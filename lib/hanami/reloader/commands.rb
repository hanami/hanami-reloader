# frozen_string_literal: true

require "hanami/port"

module Hanami
  module Reloader
    module Commands
      # Guardfile
      module Guardfile
        def self.group
          "server"
        end

        def self.default_path
          path("Guardfile")
        end

        def self.path(value)
          value
        end
      end

      # Generate hanami-reloader configuration
      class Install < Hanami::CLI::Command
        # @api private
        # @since 2.1.0
        #
        # NOTE: Any change to this constant MUST be reflected in the `#generate_configuration` method,
        #       by copying and pasting this regex.
        MATCHER = %r{^(app|config|lib|slices)([\\/][^\\/]+)*\.(rb|erb|haml|slim)$}i

        desc "Generate configuration for code reloading"

        def initialize(fs: Dry::Files.new, **args)
          super
        end

        def call(*, **)
          generate_configuration(Guardfile.default_path)
        end

        private

        def generate_configuration(path)
          fs.write path, <<~CODE
            # frozen_string_literal: true

            group :#{Guardfile.group} do
              guard "puma", port: ENV.fetch("#{Hanami::Port::ENV_VAR}", #{Hanami::Port::DEFAULT}), environment: ENV.fetch("HANAMI_ENV", "development") do
                # Edit the following regular expression for your needs.
                # See: https://guides.hanamirb.org/app/code-reloading/
                watch(%r{^(app|config|lib|slices)([\\/][^\\/]+)*.(rb|erb|haml|slim)$}i)
              end
            end
          CODE
        end
      end

      # Override `hanami server` command
      class Server < Hanami::CLI::Commands::App::Server
        # @since 2.0.0
        # @api private
        DEFAULT_GUARD_PUMA_OPTIONS = ["-n", "f", "-i", "-g", Guardfile.group, "-G"].freeze

        # @since 2.0.0
        # @api private
        OPTIONS_SEPARATOR = " "

        option :guardfile,      type: :string,  desc: "Path to Guardfile", default: Guardfile.default_path.to_s
        option :code_reloading, type: :boolean, desc: "Code reloading",    default: true

        desc "Start Hanami app server"

        example [
          "--no-code-reloading # Disable code reloading"
        ]

        def call(**args)
          code_reloading = args.fetch(:code_reloading)

          if ENV["HANAMI_ENV"] == "production"
            out.puts "WARNING: You are running hanami server in production environment, " \
                     "code reloading is disabled but hanami server is intended to be used only on development. " \
                     "For production, you should use the rack handler command directly (i.e. `bundle exec puma -C " \
                     "config/puma.rb`)."
            return super
          end

          if code_reloading
            guard_puma_env_vars!(**args)
            exec "bundle exec guard #{guard_puma_options(**args)}"
          else
            super
          end
        end

        private

        def guard_puma_env_vars!(**args)
          Hanami::Port.call!(args.fetch(:port))
        end

        def guard_puma_options(**args)
          options = DEFAULT_GUARD_PUMA_OPTIONS.dup
          options.push(Guardfile.path(args.fetch(:guardfile)))
          options.join(OPTIONS_SEPARATOR)
        end
      end
    end
  end
end
