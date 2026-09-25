# frozen_string_literal: true

module Hanami
  module Reloader
    # Detects changes to an app's source files by comparing their modification times.
    #
    # Nothing runs in the background: files are stat'd when {#updated?} is called, which the
    # reloader does once per request. This needs no native extensions, behaves the same on every
    # platform, and means a reload only ever happens between requests. Only the directories Hanami
    # loads code from are walked, so the cost is proportional to the app rather than to the project
    # (`node_modules/` and friends are never visited).
    #
    # @api private
    # @since 3.1.0
    class FileChecker
      # Directories whose contents {Hanami::Slice#reload} is able to pick up.
      #
      # @api private
      # @since 3.1.0
      WATCHED_DIRS = %w[app config lib slices].freeze

      # @api private
      # @since 3.1.0
      WATCHED_EXTENSIONS = %w[rb erb haml slim].freeze

      # Files that a reload cannot apply, because they are loaded once before the app exists.
      #
      # @api private
      # @since 3.1.0
      RESTART_REQUIRED_PATHS = [
        File.join("config", "app.rb"),
        "Gemfile",
        "Gemfile.lock"
      ].freeze

      # @api private
      # @since 3.1.0
      attr_reader :root

      # @api private
      # @since 3.1.0
      def initialize(root:)
        @root = Pathname(root)
        @glob = File.join("**", "*.{#{WATCHED_EXTENSIONS.join(",")}}")
        @signature = reloadable_signature
        @seen = @signature
        @failed = nil
        @restart_mtimes = restart_required_mtimes
      end

      # Returns true if any reloadable file has changed since the last {#commit!}, and that change
      # has not already been reported to {#failed!}.
      #
      # This deliberately does not record what it saw as the new baseline. Until {#commit!} is
      # called the change is still considered outstanding, so a reload that raises is never taken
      # as having been applied.
      #
      # @return [Boolean]
      #
      # @api private
      # @since 3.1.0
      def updated?
        @seen = reloadable_signature

        # A failed reload leaves the app torn down, so once one has failed anything other than the
        # state that failed needs a reload, even the state that was last committed.
        return @seen != @failed if @failed

        @seen != @signature
      end

      # Accepts the current state of the files as the new baseline.
      #
      # @api private
      # @since 3.1.0
      def commit!
        @signature = reloadable_signature
        @failed = nil
        self
      end

      # Records that reloading the files seen by the last {#updated?} did not succeed.
      #
      # Nothing is committed: the change stays outstanding, so saving a fix is still picked up.
      # What this does stop is {#updated?} reporting that same state again, which would otherwise
      # have every request re-run a reload already known to raise.
      #
      # @api private
      # @since 3.1.0
      def failed!
        @failed = @seen
        self
      end

      # Returns the paths of any changed files that a reload cannot apply.
      #
      # Unlike {#updated?} this records what it saw, so each change is reported once.
      #
      # @return [Array<String>] paths relative to the app root, empty if nothing changed
      #
      # @api private
      # @since 3.1.0
      def restart_required
        current = restart_required_mtimes

        changed = current.reject { |path, mtime| @restart_mtimes[path] == mtime }.keys
        @restart_mtimes = current

        changed
      end

      private

      def reloadable_signature
        paths = WATCHED_DIRS.flat_map { |dir| Dir.glob(root.join(dir, @glob)) }

        # `config/app.rb` sits inside a watched directory but cannot be applied by a reload, so it
        # is excluded here and reported by {#restart_required?} instead. Otherwise every edit to it
        # would both warn and trigger a reload that changes nothing.
        signature(paths - restart_required_paths)
      end

      def restart_required_paths
        @restart_required_paths ||= RESTART_REQUIRED_PATHS.map { |path| root.join(path).to_s }
      end

      # Keyed by the relative path so a change can be reported by name, and tracked individually so
      # that touching one file does not mask a change to another.
      def restart_required_mtimes
        RESTART_REQUIRED_PATHS.to_h do |path|
          [path, File.mtime(root.join(path)).to_f]
        rescue Errno::ENOENT
          [path, nil]
        end
      end

      # A file count alongside the newest mtime. Between them these catch the three things that
      # matter: a file changing (mtime moves), one being added, and one being deleted (count
      # moves). Comparing counts avoids having to keep a hash of every path.
      def signature(paths)
        count = 0
        latest = 0.0

        paths.each do |path|
          mtime = File.mtime(path).to_f
          count += 1
          latest = mtime if mtime > latest
        rescue Errno::ENOENT
          # Deleted between the glob and the stat; the next check will see a stable state.
        end

        [count, latest]
      end
    end
  end
end
