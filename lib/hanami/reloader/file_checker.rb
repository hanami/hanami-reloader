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

      # Ruby files and templates, plus YAML files such as settings files and translations.
      #
      # @api private
      # @since 3.1.0
      WATCHED_EXTENSIONS = %w[rb erb haml slim yml yaml].freeze

      # Directories whose files are all watched, whatever their extension.
      #
      # Templates can be in any format that Tilt supports, and their names can end in any extension
      # (such as `.html.erb` or `.json.yajl`), so watching them by extension would miss some. This
      # matches `app/templates/` as well as the `templates/` dir of every slice, nested slices too.
      #
      # @api private
      # @since 3.1.0
      WATCHED_ANY_FILE_DIRS = %w[templates].freeze

      # Files that a reload cannot apply, because they are loaded once before the app exists.
      #
      # @api private
      # @since 3.1.0
      RESTART_REQUIRED_PATHS = [
        File.join("config", "app.rb"),
        "Gemfile",
        "Gemfile.lock"
      ].freeze

      # `.env` files, which a reload also cannot apply.
      #
      # Hanami loads these once, when loading `config/app.rb`. Since a reload keeps that class,
      # Hanami never loads these .env files again. Even if it did, dotenv does not overwrite values
      # already in `ENV`.
      #
      # This matches `.env` and `.env.*`, but not names like `.envrc`. It matches some files Hanami
      # does not load for the current env (such as `.env.test` in development), but those are
      # rarely edited while the server runs.
      #
      # @api private
      # @since 3.1.0
      DOTENV_GLOB = ".env{,.*}"

      # @api private
      # @since 3.1.0
      attr_reader :root

      # @api private
      # @since 3.1.0
      def initialize(root:)
        @root = Pathname(root)
        @globs = [
          File.join("**", "*.{#{WATCHED_EXTENSIONS.join(",")}}"),
          File.join("**", "{#{WATCHED_ANY_FILE_DIRS.join(",")}}", "**", "*")
        ]
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

      # Accepts the files seen by the last {#updated?} as the new baseline.
      #
      # The files are not checked again here. A file saved while the reload was running may not
      # have been loaded, so it must stay outstanding for the next {#updated?} to report.
      #
      # @api private
      # @since 3.1.0
      def commit!
        @signature = @seen
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
        # A deleted `.env` file is no longer globbed, but its values are still in `ENV`.
        changed += @restart_mtimes.keys - current.keys
        @restart_mtimes = current

        changed
      end

      private

      def reloadable_signature
        # A template with a watched extension matches both globs, so remove the duplicates.
        paths = WATCHED_DIRS.flat_map { |dir|
          @globs.flat_map { |glob| Dir.glob(root.join(dir, glob)) }
        }.uniq

        # `config/app.rb` sits inside a watched directory but cannot be applied by a reload, so it
        # is excluded here and reported by {#restart_required} instead. Otherwise every edit to it
        # would both warn and trigger a reload that changes nothing.
        signature(paths - restart_required_paths)
      end

      def restart_required_paths
        @restart_required_paths ||= RESTART_REQUIRED_PATHS.map { |path| root.join(path).to_s }
      end

      # Keyed by the relative path so a change can be reported by name, and tracked individually so
      # that touching one file does not mask a change to another.
      def restart_required_mtimes
        (RESTART_REQUIRED_PATHS + Dir.glob(DOTENV_GLOB, base: root)).to_h do |path|
          [path, File.mtime(root.join(path)).to_f]
        rescue Errno::ENOENT
          [path, nil]
        end
      end

      # A hash of every file's path and mtime. A change to any file gives a different hash: a file
      # being edited, added, deleted or renamed, and even an mtime moving backwards (such as a file
      # restored from a backup).
      #
      # Only the hash is kept between requests, so memory does not grow with the app.
      #
      # `Dir.glob` returns paths sorted, so the same files always give the same hash.
      #
      # Directories are skipped. The templates glob matches them too, and a directory's mtime
      # changes whenever a file is added to it, such as an editor's swap file when a template is
      # opened. That would cause a reload when nothing has been edited.
      def signature(paths)
        entries = paths.filter_map do |path|
          stat = File.stat(path)
          next if stat.directory?

          [path, stat.mtime.to_f]
        rescue Errno::ENOENT
          # Deleted between the glob and the stat; the next check will see a stable state.
          nil
        end

        entries.hash
      end
    end
  end
end
