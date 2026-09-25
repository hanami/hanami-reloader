# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Hanami::Reloader::FileChecker do
  subject(:file_checker) { described_class.new(root: dir) }

  let(:dir) { Pathname(Dir.mktmpdir) }

  after { FileUtils.remove_entry(dir) }

  def write(path, content = "# frozen_string_literal: true\n")
    full = dir.join(path)
    full.dirname.mkpath
    full.write(content)
    full
  end

  # mtime has one-second granularity on some filesystems, so move times explicitly rather than
  # relying on the clock advancing between writes.
  def touch(path, offset: 10)
    full = dir.join(path)
    time = Time.now + offset
    File.utime(time, time, full)
  end

  before { write("app/greeter.rb") }

  describe "#updated?" do
    it "is false when nothing has changed" do
      expect(file_checker.updated?).to be(false)
    end

    it "is true when a watched file is modified" do
      file_checker
      touch("app/greeter.rb")

      expect(file_checker.updated?).to be(true)
    end

    it "is true when a watched file is added" do
      file_checker
      write("app/farewell.rb")
      touch("app/farewell.rb")

      expect(file_checker.updated?).to be(true)
    end

    it "is true when a watched file is deleted" do
      file_checker
      FileUtils.rm(dir.join("app/greeter.rb"))

      expect(file_checker.updated?).to be(true)
    end

    it "is true when a watched file is renamed" do
      file_checker
      FileUtils.mv(dir.join("app/greeter.rb"), dir.join("app/welcomer.rb"))

      expect(file_checker.updated?).to be(true)
    end

    it "is true when a watched file's mtime moves backwards" do
      write("app/farewell.rb")
      touch("app/farewell.rb", offset: 10)
      file_checker

      # Older than the newest file, such as a file restored from a backup.
      touch("app/greeter.rb", offset: -100)

      expect(file_checker.updated?).to be(true)
    end

    it "watches config, lib and slices as well as app" do
      %w[config/routes.rb lib/thing.rb slices/main/action.rb].each do |path|
        w = described_class.new(root: dir)
        write(path)
        touch(path)

        expect(w.updated?).to be(true), "expected a change in #{path} to be seen"
      end
    end

    it "sees template files, not just Ruby" do
      file_checker
      write("app/templates/home.html.erb", "<h1>hi</h1>")
      touch("app/templates/home.html.erb")

      expect(file_checker.updated?).to be(true)
    end

    it "ignores files outside the watched directories" do
      file_checker
      write("node_modules/pkg/index.rb")
      write("public/assets/app.rb")
      touch("node_modules/pkg/index.rb")
      touch("public/assets/app.rb")

      expect(file_checker.updated?).to be(false)
    end

    it "does not treat config/app.rb as reloadable, since a reload cannot apply it" do
      write("config/app.rb")
      w = described_class.new(root: dir)
      touch("config/app.rb")

      expect(w.updated?).to be(false)
      expect(w.restart_required).to eq(["config/app.rb"])
    end

    it "keeps reporting a change until it is committed" do
      file_checker
      touch("app/greeter.rb")

      expect(file_checker.updated?).to be(true)
      expect(file_checker.updated?).to be(true)

      file_checker.commit!

      expect(file_checker.updated?).to be(false)
    end
  end

  describe "#commit!" do
    it "keeps reporting a change made after the last check, since the reload may have missed it" do
      file_checker
      touch("app/greeter.rb", offset: 10)
      file_checker.updated?

      # Saved while the reload is running, between the check and the commit.
      touch("app/greeter.rb", offset: 20)
      file_checker.commit!

      expect(file_checker.updated?).to be(true)
    end
  end

  describe "#failed!" do
    it "stops reporting the change that failed, so it is not retried on every request" do
      file_checker
      touch("app/greeter.rb")

      expect(file_checker.updated?).to be(true)

      file_checker.failed!

      expect(file_checker.updated?).to be(false)
    end

    it "reports again as soon as the files change, so a fix is picked up" do
      file_checker
      touch("app/greeter.rb", offset: 10)
      file_checker.updated?
      file_checker.failed!

      touch("app/greeter.rb", offset: 20)

      expect(file_checker.updated?).to be(true)
    end

    it "reports a return to the committed state, since the failed reload tore the app down" do
      file_checker
      write("app/broken.rb")
      file_checker.updated?
      file_checker.failed!

      FileUtils.rm(dir.join("app/broken.rb"))

      expect(file_checker.updated?).to be(true)
    end

    it "does not commit, so the change is still outstanding" do
      file_checker
      touch("app/greeter.rb", offset: 10)
      file_checker.updated?
      file_checker.failed!

      # Reverting to the state that was last committed is a change too, and must be seen.
      touch("app/greeter.rb", offset: 20)
      expect(file_checker.updated?).to be(true)

      file_checker.commit!
      file_checker.failed!

      expect(file_checker.updated?).to be(false)
    end
  end

  describe "#restart_required" do
    before { write("config/app.rb") }

    it "is empty when nothing has changed" do
      expect(file_checker.restart_required).to be_empty
    end

    it "names the changed file, and reports it once" do
      file_checker
      touch("config/app.rb")

      expect(file_checker.restart_required).to eq(["config/app.rb"])
      expect(file_checker.restart_required).to be_empty
    end

    it "reports a change to the Gemfile" do
      write("Gemfile")
      checker = described_class.new(root: dir)
      touch("Gemfile")

      expect(checker.restart_required).to eq(["Gemfile"])
    end

    it "tracks each file separately, so one change does not mask another" do
      write("Gemfile")
      checker = described_class.new(root: dir)

      touch("config/app.rb", offset: 10)
      expect(checker.restart_required).to eq(["config/app.rb"])

      touch("Gemfile", offset: 20)
      expect(checker.restart_required).to eq(["Gemfile"])
    end
  end
end
