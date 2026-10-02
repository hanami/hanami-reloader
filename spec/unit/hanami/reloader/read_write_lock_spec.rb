# frozen_string_literal: true

RSpec.describe Hanami::Reloader::ReadWriteLock do
  subject(:lock) { described_class.new }

  # Waits until the thread is blocked, so a spec never races ahead of it.
  #
  # A thread also sleeps while it waits for the lock's internal mutex, not only while it waits for
  # the lock itself. That is fine here: the lock never holds its mutex while it waits, so a sleeping
  # thread has not taken the lock either way.
  def wait_until_blocked(thread)
    Thread.pass until thread.status == "sleep" || !thread.alive?
  end

  # Waits for the thread to finish and returns its value. A lock bug can leave a thread blocked
  # forever, so this fails after a time limit instead of hanging the suite.
  def finish(thread, timeout: 2)
    unless thread.join(timeout)
      thread.kill
      raise "thread was still blocked after #{timeout}s"
    end

    thread.value
  end

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  # Drains a queue into an array, in the order its items were pushed.
  def drain(queue)
    Array.new(queue.size) { queue.pop }
  end

  describe "read locks" do
    it "can be held by many readers at once" do
      lock.acquire_read_lock
      lock.acquire_read_lock

      expect(lock.readers).to eq(2)
    end

    it "can be released from a thread other than the one that acquired it" do
      lock.acquire_read_lock

      Thread.new { lock.release_read_lock }.join

      expect(lock.readers).to eq(0)
    end

    it "cannot be released when none is held" do
      expect { lock.release_read_lock }.to raise_error(ThreadError)
    end

    it "waits while a writer holds the lock" do
      release = Queue.new
      writer = Thread.new { lock.with_write_lock(timeout: 1) { release.pop } }
      wait_until_blocked(writer)

      reader = Thread.new { lock.acquire_read_lock }
      wait_until_blocked(reader)

      expect(lock.readers).to eq(0)

      release << true
      finish(reader)

      expect(lock.readers).to eq(1)
    end
  end

  describe "#with_write_lock" do
    it "runs the block and returns true when the lock is free" do
      ran = false

      expect(lock.with_write_lock(timeout: 0) { ran = true }).to be(true)
      expect(ran).to be(true)
    end

    it "waits for readers to release their locks" do
      lock.acquire_read_lock
      ran = Queue.new

      writer = Thread.new { lock.with_write_lock(timeout: 5) { ran << true } }
      wait_until_blocked(writer)

      expect(ran).to be_empty

      lock.release_read_lock

      expect(finish(writer)).to be(true)
      expect(ran.size).to eq(1)
    end

    it "gives up without running the block when readers outlast the timeout" do
      lock.acquire_read_lock
      ran = false

      started = now
      expect(lock.with_write_lock(timeout: 0.05) { ran = true }).to be(false)

      expect(now - started).to be >= 0.05
      expect(ran).to be(false)
    end

    it "gives up at once with a timeout of zero" do
      lock.acquire_read_lock

      expect(lock.with_write_lock(timeout: 0) { raise "not reached" }).to be(false)
    end

    it "keeps new readers out while it waits, and lets them in when it gives up" do
      lock.acquire_read_lock

      writer = Thread.new { lock.with_write_lock(timeout: 0.2) { raise "not reached" } }
      wait_until_blocked(writer)

      # Without this, a steady flow of readers could keep the writer out forever.
      reader = Thread.new { lock.acquire_read_lock }
      wait_until_blocked(reader)

      expect(lock.readers).to eq(1)

      expect(finish(writer)).to be(false)
      finish(reader)

      expect(lock.readers).to eq(2)
    end

    it "goes ahead of readers that queued while it waited" do
      order = Queue.new
      lock.acquire_read_lock

      writer = Thread.new do
        lock.with_write_lock(timeout: 5) { order << [:writer, lock.readers] }
      end
      wait_until_blocked(writer)

      reader = Thread.new do
        lock.acquire_read_lock
        order << [:reader, nil]
        lock.release_read_lock
      end
      wait_until_blocked(reader)

      # The last reader leaves. The writer must go next, before the reader queued behind it.
      lock.release_read_lock

      expect(finish(writer)).to be(true)
      finish(reader)

      expect(drain(order)).to eq([[:writer, 0], [:reader, nil]])
    end

    it "lets readers in if its thread is killed while it waits" do
      lock.acquire_read_lock

      writer = Thread.new { lock.with_write_lock(timeout: 5) { raise "not reached" } }
      wait_until_blocked(writer)

      reader = Thread.new { lock.acquire_read_lock }
      wait_until_blocked(reader)

      # The queued reader would otherwise wait forever for a writer that no longer exists.
      writer.kill.join

      finish(reader)

      expect(lock.readers).to eq(2)
    end

    it "is held by one writer at a time" do
      release = Queue.new
      first = Thread.new { lock.with_write_lock(timeout: 0) { release.pop } }
      wait_until_blocked(first)

      expect(lock.with_write_lock(timeout: 0) { raise "not reached" }).to be(false)

      ran = Queue.new
      second = Thread.new { lock.with_write_lock(timeout: 5) { ran << true } }
      wait_until_blocked(second)

      expect(ran).to be_empty

      release << true

      expect(finish(first)).to be(true)
      expect(finish(second)).to be(true)
      expect(ran.size).to eq(1)
    end

    it "releases the lock when the block raises" do
      expect { lock.with_write_lock(timeout: 0) { raise "boom" } }.to raise_error("boom")

      expect(lock.with_write_lock(timeout: 0) {}).to be(true)
    end
  end

  # Stress test many threads at once, checking that no reader ever runs at the same time as a
  # writer. This along won't prove the lock correct, but it can catch a mistake the specs above did
  # not think of.
  it "never lets a reader run alongside a writer, or two writers run together" do
    state = Mutex.new
    active_readers = 0
    active_writers = 0
    overlaps = 0
    writes = 0

    readers = Array.new(8) do
      Thread.new do
        200.times do
          lock.acquire_read_lock
          state.synchronize do
            active_readers += 1
            overlaps += 1 if active_writers.positive?
          end
          Thread.pass
          state.synchronize { active_readers -= 1 }
          lock.release_read_lock
        end
      end
    end

    writers = Array.new(2) do
      Thread.new do
        100.times do
          lock.with_write_lock(timeout: 1) do
            state.synchronize do
              active_writers += 1
              writes += 1
              overlaps += 1 if active_readers.positive? || active_writers > 1
            end
            Thread.pass
            state.synchronize { active_writers -= 1 }
          end
        end
      end
    end

    (readers + writers).each { |thread| finish(thread, timeout: 10) }

    expect(overlaps).to eq(0)
    expect(writes).to be_positive
    expect(lock.readers).to eq(0)
  end
end
