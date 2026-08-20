# frozen_string_literal: true

module Hanami
  module Reloader
    # Rack middleware that reloads the app in place when its source files change.
    #
    # This sits *outside* the Hanami app rather than in the app's own middleware stack, because a
    # reload replaces everything inside that stack. Wrapping from the outside means the request is
    # dispatched into freshly loaded code, instead of into the code that was live when the request
    # arrived.
    #
    # Files are checked once per request rather than watched in the background, so a reload only
    # happens when there is something to serve, and never lands halfway through an edit.
    #
    # @api private
    # @since 3.1.0
    class Middleware
      # @api private
      # @since 3.1.0
      def initialize(app, file_checker:, slice: nil, out: $stdout)
        @app = app
        @file_checker = file_checker
        @slice = slice
        @out = out
        @mutex = Mutex.new
      end

      # @api private
      # @since 3.1.0
      def call(env)
        @mutex.synchronize { check_for_changes }

        @app.call(env)
      end

      private

      # @api private
      # @since 3.1.0
      def check_for_changes
        restart_required = @file_checker.restart_required
        warn_restart_required(restart_required) if restart_required.any?

        return unless @file_checker.updated?

        reload!

        # Only once the reload has succeeded, so a file that raises is retried on the next request
        # instead of being silently skipped.
        @file_checker.commit!
      end

      # @api private
      # @since 3.1.0
      def reload!
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        slice.reload!

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @out.puts("[hanami] Reloaded in #{(elapsed * 1000).round}ms")
      end

      # @api private
      # @since 3.1.0
      def warn_restart_required(paths)
        @out.puts(
          "[hanami] #{paths.join(', ')} cannot be reloaded. " \
          "Restart the server to apply your changes."
        )
      end

      # Resolved lazily: the middleware is built while the app is being loaded.
      #
      # @api private
      # @since 3.1.0
      def slice
        @slice || Hanami.app
      end
    end
  end
end
