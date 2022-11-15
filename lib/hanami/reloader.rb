# frozen_string_literal: true

require "hanami/cli"
require "zeitwerk"

module Hanami
  # Hanami reloader
  module Reloader
    # @since 2.0.0
    # @api private
    def self.gem_loader
      @gem_loader ||= Zeitwerk::Loader.new.tap do |loader|
        root = File.expand_path("..", __dir__)
        loader.tag = "hanami-reloader"
        loader.inflector = Zeitwerk::GemInflector.new("#{root}/hanami-reloader.rb")
        loader.push_dir(root)
        loader.ignore(
          "#{root}/hanami-reloader.rb",
          "#{root}/hanami/controller/version.rb"
        )
      end
    end

    gem_loader.setup
    require_relative "reloader/version"

    if Hanami::CLI.within_hanami_app?
      Hanami::CLI.after "install", Commands::Install
      Hanami::CLI.register "server", Commands::Server
    end
  end
end
