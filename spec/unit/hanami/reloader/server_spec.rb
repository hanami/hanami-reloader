# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Hanami::Reloader::Server do
  subject(:server) { described_class.new(rack_server: rack_server, out: out, err: err) }

  let(:rack_server) do
    Class.new do
      attr_reader :options

      def start(options) = @options = options
    end.new
  end

  let(:out) { StringIO.new }
  let(:err) { StringIO.new }
  let(:dir) { Pathname(Dir.mktmpdir) }

  let(:code_reloading) { true }

  before do
    dir.join("config.ru").write(<<~RUBY)
      run ->(_env) { [200, {}, ["from config.ru"]] }
    RUBY

    allow(Hanami).to receive(:app).and_return(
      double("app", root: dir, config: double("config", code_reloading: code_reloading))
    )
  end

  after { FileUtils.remove_entry(dir) }

  def call(**options)
    Dir.chdir(dir) { server.call(config: "config.ru", **options) }
  end

  it "inherits the option mapping from Hanami::CLI::Server" do
    call(host: "127.0.0.3", port: 2000, debug: true, warn: false)

    expect(rack_server.options[:Host]).to eq("127.0.0.3")
    expect(rack_server.options[:Port]).to be(2000)
    expect(rack_server.options[:debug]).to be(true)
  end

  it "serves the app from config.ru, wrapped in the reloader middleware" do
    call

    app = rack_server.options[:app]

    expect(app).to be_a(Hanami::Reloader::Middleware)
    expect(app.call({})).to eq([200, {}, ["from config.ru"]])
  end

  it "reads the config file given by the config option" do
    dir.join("custom.ru").write(<<~RUBY)
      run ->(_env) { [200, {}, ["from custom.ru"]] }
    RUBY

    Dir.chdir(dir) { server.call(config: "custom.ru") }

    expect(rack_server.options[:app].call({})).to eq([200, {}, ["from custom.ru"]])
  end

  context "when the app has code reloading disabled" do
    let(:code_reloading) { false }

    it "warns and serves the app unwrapped" do
      call

      expect(err.string).to include("`config.code_reloading` is false")
      expect(rack_server.options[:app]).not_to be_a(Hanami::Reloader::Middleware)
      expect(rack_server.options[:app].call({})).to eq([200, {}, ["from config.ru"]])
    end
  end
end
