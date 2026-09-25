# frozen_string_literal: true

require "concurrent/atomic/read_write_lock"
require "rack/body_proxy"

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
    class Middleware
      # Rack env key carrying a failed reload's exception to {RERAISE}.
      RELOAD_ERROR = "hanami.reloader.reload_error"

      # The app underneath the reloader's own webconsole middleware.
      #
      # Webconsole renders what is raised *below* it, but a reload error was raised before the
      # request arrived. Raising it again here is what puts it back underneath webconsole. Ruby
      # leaves the backtrace of an exception that already has one alone when it is re-raised, so
      # the page still describes the reload rather than this line.
      RERAISE = ->(env) { raise env.fetch(RELOAD_ERROR) }

      def initialize(app, file_checker:, slice: nil, out: $stdout)
        @app = app
        @file_checker = file_checker
        @slice = slice
        @out = out
        @check_mutex = Mutex.new
        @lock = Concurrent::ReadWriteLock.new
        @reload_error = nil
        @error_app = nil
      end

      def call(env)
        # While a reload is failing, console requests are the rendered error page asking for more
        # detail about the very error being shown. Checking for changes first would retry a reload
        # already known to raise, for a request that is not going to reach the app either way.
        reload_if_needed unless @reload_error && console_request?(env)

        dispatch(env)
      end

      private

      def reload_if_needed
        # `FileChecker` is not thread-safe, and `restart_required` reports each change once, so it
        # must be consulted on every request and by one thread at a time.
        @check_mutex.synchronize do
          restart_required = @file_checker.restart_required
          warn_restart_required(restart_required) if restart_required.any?

          reload_slice if @file_checker.updated?
        end
      end

      # Reloads the slice, and records whether the reload failed so requests can act on it.
      #
      # Must not be called while this thread holds a read lock. The write lock waits for every
      # reader, including this thread, so it would wait forever.
      def reload_slice
        # Reload under the write lock, so no request runs in the app while it is torn down, and a
        # waiting request sees a possible failure as soon as it gets the read lock.
        @lock.with_write_lock do
          reload
          @reload_error = nil
          @file_checker.commit!
        rescue StandardError, ScriptError => exception
          # Include `ScriptError` (covering `SyntaxError` and `LoadError`) as a likely error to come
          # from a reload. Ignore anything broader (such as `Interrupt` or `NoMemoryError`), as
          # unlikely to be an app code concern.

          @reload_error = exception
          @error_app ||= build_error_app
          @file_checker.failed!
        end
      end

      # Dispatches the request to the app, or renders the error if the last reload failed.
      #
      # Holds a read lock until the response body is closed. Requests can run at the same time as
      # each other, but never at the same time as a reload.
      def dispatch(env)
        @lock.acquire_read_lock
        held = true

        begin
          # Never dispatch after a failed reload, which unloads before it prepares, leaving us a
          # half-built app whose own errors would only obscure the real one.
          #
          # Check this after taking the lock, not before: if a reload was running when this request
          # arrived, the request has now waited for it to finish, so it can see whether it failed.
          return render_reload_error(env, @reload_error) if @reload_error

          status, headers, body = @app.call(env)

          # Rack bodies can be lazy, so returning from `call` does not mean the response has been
          # written. Hold the lock until the body is closed, or a reload could pull the app out
          # from under it mid-response.
          proxied = Rack::BodyProxy.new(body) { @lock.release_read_lock }
          held = false

          [status, headers, proxied]
        ensure
          @lock.release_read_lock if held
        end
      end

      # Renders the failed reload, so it is presented like any other error in development.
      def render_reload_error(env, error)
        # Nothing here can render it, so do what the reloader has always done and let it reach
        # the server.
        raise error unless @error_app

        env[RELOAD_ERROR] = error
        @error_app.call(env)
      end

      def console_request?(env)
        return false unless @error_app

        env["PATH_INFO"].to_s.start_with?(Hanami::Webconsole::MOUNT_PATH)
      end

      # Builds the middleware that renders a failed reload.
      #
      # This is the reloader's own webconsole instance rather than the app's, which is inside the
      # stack the failed reload has just torn down. It is built once and kept for the life of the
      # process, because the console on the page it renders addresses error pages by id in that
      # instance's registry, over later requests.
      #
      # @return [#call, nil] nil when webconsole cannot render the error
      def build_error_app
        return nil unless render_detailed_errors?

        # Normally already loaded: the app's own stack requires it under this same condition.
        require "hanami/webconsole" unless defined?(Hanami::Webconsole::Middleware)

        Hanami::Webconsole::Middleware.new(RERAISE, slice.config)
      rescue LoadError
        nil
      end

      # Gated exactly as Hanami gates webconsole in the app's own middleware stack, so the
      # reloader never shows a detailed error page where the app would not have.
      def render_detailed_errors?
        Hanami.bundled?("hanami-webconsole") && slice.config.render_detailed_errors
      end

      def reload
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

        slice.reload

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        @out.puts("[hanami] Reloaded in #{(elapsed * 1000).round}ms")
      end

      def warn_restart_required(paths)
        @out.puts(
          "[hanami] #{paths.join(', ')} cannot be reloaded. " \
          "Restart the server to apply your changes."
        )
      end

      # Resolved lazily: the middleware is built while the app is being loaded.
      def slice
        @slice || Hanami.app
      end
    end
  end
end
