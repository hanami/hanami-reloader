# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe Hanami::Reloader::Commands::Server do
  subject(:command) { described_class.new(server: server, out: out, err: err) }

  let(:captured) { {} }
  let(:server) do
    spy("server").tap { |s| allow(s).to receive(:call) { |**kwargs| captured.replace(kwargs) } }
  end
  let(:out) { StringIO.new }
  let(:err) { StringIO.new }

  let(:args) { {code_reloading: code_reloading, port: port} }
  let(:code_reloading) { true }
  let(:port) { Hanami::Port::DEFAULT }

  before { ENV.delete("HANAMI_PORT") }
  after { ENV.delete("HANAMI_PORT") }

  # The reloading runner is covered by its own spec; here we only care that the command reaches
  # for it, and with which options.
  let(:reloading_server) { spy("reloading server") }
  before do
    allow(command).to receive(:reloading_server).and_return(reloading_server)
    allow(reloading_server).to receive(:call) { |**kwargs| captured.replace(kwargs) }
  end

  describe "#call" do
    context "with code reloading enabled" do
      it "serves through the reloading runner rather than the plain one" do
        command.call(**args)

        expect(reloading_server).to have_received(:call)
        expect(server).not_to have_received(:call)
      end

      it "does not shell out to Guard" do
        expect(command).not_to receive(:exec)

        command.call(**args)
      end

      context "without a port in the environment" do
        it "does not set HANAMI_PORT" do
          command.call(**args)

          expect(ENV.fetch("HANAMI_PORT", nil)).to be(nil)
        end

        context "with a custom port CLI option" do
          let(:port) { 9000 }

          it "sets HANAMI_PORT and serves on that port" do
            command.call(**args)

            expect(ENV.fetch("HANAMI_PORT", nil)).to eq("9000")
            expect(captured[:port]).to eq(9000)
          end
        end
      end

      context "with a port in the environment" do
        before { ENV["HANAMI_PORT"] = "9000" }

        it "serves on the environment's port" do
          command.call(**args)

          expect(ENV.fetch("HANAMI_PORT", nil)).to eq("9000")
          expect(captured[:port]).to eq(9000)
        end

        context "with a custom port CLI option" do
          let(:port) { 18_000 }

          it "lets the CLI option win" do
            command.call(**args)

            expect(ENV.fetch("HANAMI_PORT", nil)).to eq("18000")
            expect(captured[:port]).to eq(18_000)
          end
        end
      end
    end

    context "with code reloading disabled" do
      let(:code_reloading) { false }

      it "serves through the plain runner" do
        command.call(**args)

        expect(server).to have_received(:call)
        expect(reloading_server).not_to have_received(:call)
      end
    end

    context "in the production environment" do
      before { ENV["HANAMI_ENV"] = "production" }
      after { ENV.delete("HANAMI_ENV") }

      it "warns" do
        command.call(**args)

        expect(err.string).to include(
          "WARNING: You are running `hanami server` in the production environment via hanami-reloader."
        )
      end

      it "serves through the plain runner, despite code reloading being enabled" do
        command.call(**args)

        expect(server).to have_received(:call)
        expect(reloading_server).not_to have_received(:call)
      end
    end
  end
end
