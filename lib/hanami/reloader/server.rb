# frozen_string_literal: true

require "hanami/cli/server"
require "rack/builder"

module Hanami
  module Reloader
    # Runs the rack server against an app wrapped in {Middleware}.
    #
    # Hanami's own middleware stack lives inside `Hanami.app`, which a reload replaces wholesale.
    # The reloader therefore has to sit outside the app, and the only place outside it - short of
    # every app editing its `config.ru` - is between the rack config file being read and the server
    # being started.
    #
    # `Hanami::CLI::Server` hands the rack server a path to `config.ru` and lets it load the file,
    # leaving no seam there. Subclassing it opens one while still inheriting its option mapping and
    # its choice of rack server, so nothing about how a Hanami app is served is duplicated here.
    #
    # @api private
    # @since 3.1.0
    class Server < Hanami::CLI::Server
      # @api private
      # @since 3.1.0
      def initialize(out: $stdout, err: $stderr, **opts)
        super(**opts)
        @out = out
        @err = err
      end

      # @api private
      # @since 3.1.0
      def call(**options)
        rack_options = Hash[
          extract_rack_fallback_options(options) + extract_overriding_options(options)
        ]

        # Read here rather than by the caller, so a `--config` option is honoured.
        rack_options[:app] = wrap(Rack::Builder.parse_file(rack_options.fetch(:config)))

        rack_server.start(rack_options)
      end

      private

      # The app is only available once the rack config file has been read, so this is the first
      # point at which its config can be consulted.
      #
      # @api private
      # @since 3.1.0
      def wrap(app)
        unless Hanami.app.config.code_reloading
          @err.puts(
            "WARNING: `config.code_reloading` is false, so the app cannot be reloaded. " \
            "Starting without code reloading."
          )
          return app
        end

        Middleware.new(app, file_checker: FileChecker.new(root: Hanami.app.root), out: @out)
      end
    end
  end
end
