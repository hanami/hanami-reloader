# frozen_string_literal: true

module Hanami
  module Reloader
    # A read/write lock whose writer gives up after a timeout.
    #
    # Many readers can hold the lock at once, but a writer holds it alone. While a writer is
    # waiting, new readers wait too, so a steady flow of readers cannot keep it out. If the writer
    # gives up, those readers go ahead.
    #
    # This exists because the reloader needs a write lock that waits for readers, but only up to a
    # timeout. `Concurrent::ReadWriteLock` has no timeout, and `Concurrent::ReentrantReadWriteLock`
    # can only try for the write lock without waiting at all.
    #
    # `Concurrent::ReentrantReadWriteLock` also expects a read lock to be released by the fiber that
    # acquired it. The reloader releases its read locks when the response body is closed, and Rack
    # does not promise that happens on the same thread or fiber that called the app.
    #
    # @api private
    class ReadWriteLock
      def initialize
        @mutex = Mutex.new
        @changed = ConditionVariable.new
        @readers = 0
        @writer = false
        @waiting_writers = 0
      end

      # Returns the number of read locks currently held.
      #
      # @return [Integer]
      def readers
        @mutex.synchronize { @readers }
      end

      # Blocks until no writer holds the lock or is waiting for it, then takes a read lock.
      def acquire_read_lock
        @mutex.synchronize do
          @changed.wait(@mutex) while @writer || @waiting_writers.positive?
          @readers += 1
        end

        self
      end

      # Releases a read lock. This may be called from any thread or fiber.
      def release_read_lock
        @mutex.synchronize do
          raise ThreadError, "no read lock is held" if @readers.zero?

          @readers -= 1
          @changed.broadcast if @readers.zero?
        end

        self
      end

      # Takes the write lock and yields, waiting up to `timeout` seconds for readers to finish.
      #
      # With a timeout of zero, the lock is only taken if it is free right now.
      #
      # @param timeout [Numeric] seconds to wait for the lock
      #
      # @return [Boolean] true if the block ran, false if the lock could not be taken in time
      def with_write_lock(timeout:)
        return false unless try_acquire_write_lock(timeout)

        begin
          yield
        ensure
          release_write_lock
        end

        true
      end

      private

      def try_acquire_write_lock(timeout)
        deadline = now + timeout

        @mutex.synchronize do
          @waiting_writers += 1

          begin
            while @writer || @readers.positive?
              remaining = deadline - now
              return false if remaining <= 0

              @changed.wait(@mutex, remaining)
            end

            @writer = true
          ensure
            @waiting_writers -= 1

            # Readers queued behind this writer can go ahead if it gave up.
            @changed.broadcast unless @writer
          end
        end
      end

      def release_write_lock
        @mutex.synchronize do
          @writer = false
          @changed.broadcast
        end
      end

      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
