# frozen_string_literal: true

require "hanami/port"

module Hanami
  module Reloader
    module Commands
      # Removes configuration left behind by previous versions of hanami-reloader.
      #
      # Reloading no longer runs through Guard, so the `Guardfile` it used to generate is now
      # dead weight. Nothing is generated in its place: the reloader is wired up by the `server`
      # command below, with no per-app configuration.
      #
      # @api private
      # @since 2.1.0
      class Install < Hanami::CLI::Command
        # @api private
        # @since 3.1.0
        GUARDFILE = "Guardfile"

        desc "Remove obsolete code reloading configuration"

        def initialize(fs: Dry::Files.new, **args)
          super
        end

        def call(*, **)
          return unless fs.exist?(GUARDFILE)
          return unless fs.read(GUARDFILE).include?("guard \"puma\"")

          fs.delete(GUARDFILE)
          out.puts "Removed #{GUARDFILE} (code reloading no longer uses Guard)"
        end
      end

      # Override `hanami server` to reload the app in place instead of restarting it.
      #
      # The app is built from `config.ru` here rather than by the Rack server, so that it can be
      # wrapped in {Middleware} before being served. That keeps the reloader outside the app's own
      # middleware stack, which a reload replaces, and means an app needs no `config.ru` changes to
      # get reloading.
      #
      # @since 2.0.0
      # @api private
      class Server < Hanami::CLI::Commands::App::Server
        option :code_reloading, type: :boolean, desc: "Code reloading", default: true

        desc "Start Hanami app server"

        example [
          "--no-code-reloading # Disable code reloading"
        ]

        def call(port: Hanami::Port::DEFAULT, **args)
          return super(port: port, **args) unless code_reloading?(**args)

          # Keeps HANAMI_PORT in step with an explicit `--port`, then resolves the port the same
          # way the command we're replacing does, so a port set in `.env` is still honoured.
          Hanami::Port.call!(port)

          reloading_server.call(**args, port: Hanami::Port[port])
        end

        private

        # @api private
        # @since 3.1.0
        def code_reloading?(**args)
          return false unless args.fetch(:code_reloading)

          if ENV["HANAMI_ENV"] == "production"
            err.puts <<~TEXT
              WARNING: You are running `hanami server` in the production environment via hanami-reloader.

              Code reloading is disabled, but `hanami server` and hanami-reloader are intended to be used in
              development only.

              For production, start your web server directly, e.g. `bundle exec puma -C config/puma.rb`.
            TEXT

            return false
          end

          true
        end

        # @api private
        # @since 3.1.0
        def reloading_server
          Reloader::Server.new(out: out, err: err)
        end
      end
    end
  end
end
