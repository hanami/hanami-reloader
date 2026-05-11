# frozen_string_literal: true

require "tmpdir"

RSpec.describe Hanami::Reloader::Commands::Install do
  describe "#call" do
    subject { described_class.new(fs: fs) }

    let(:fs) { Dry::Files.new }
    let(:dir) { Dir.mktmpdir }
    let(:app) { "synth" }
    let(:app_name) { "Synth" }

    let(:arbitrary_argument) { {} }

    around do |example|
      fs.chdir(dir) { example.run }
    ensure
      fs.delete_directory(dir)
    end

    it "generates configurations" do
      subject.call(arbitrary_argument)

      # Guardfile
      matcher = Hanami::Reloader::Commands::Install::MATCHER.inspect.gsub("/^", "^").gsub("$/i", "$}i").gsub('*\\.', "*.").gsub("\\\\\\", %(\\))
      matcher = %(%r{#{matcher})
      guardfile = <<~EOF
        # frozen_string_literal: true

        group :server do
          guard "puma", port: ENV.fetch("HANAMI_PORT", 2300), environment: ENV.fetch("HANAMI_ENV", "development") do
            # Edit the following regular expression for your needs.
            # See: https://hanakai.org/learn/hanami/app/code-reloading/
            watch(#{matcher})
          end
        end
      EOF
      expect(fs.read("Guardfile")).to eq(guardfile)
    end
  end
end
