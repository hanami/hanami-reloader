# frozen_string_literal: true

require "pathname"

RSpec.describe Hanami::Reloader::Commands::Server do
  describe "#call" do
    before { ENV.delete("HANAMI_PORT") }

    let(:args) { {code_reloading: code_reloading, guardfile: guardfile, port: port} }
    let(:code_reloading) { true }
    let(:guardfile) { Hanami::Reloader::Commands::Guardfile.default_path }
    let(:port) { 2300 }
    let(:out) { StringIO.new }

    context "when in production env" do
      before { ENV["HANAMI_ENV"] = "production" }
      after { ENV.delete("HANAMI_ENV") }

      it "prints a warning when running hanami server in production" do
        allow_any_instance_of(described_class).to receive(:out).and_return(out)
        server = described_class.new(server: proc { |*| })

        expect(out).to receive(:puts).with("Warning: You are running hanami server in production environment, code reloading is disabled but hanami server is intended to be used only on development. For production, you should use the rack handler command directly (i.e. `bundle exec puma -C config/puma.rb`).")

        server.call(**args)
      end

      it "does not start guard despite code_reloading being enabled" do
        server = described_class.new(server: proc { |*| })
        expect(server).to_not receive(:exec).with("bundle exec guard -n f -i -g server -G Guardfile")

        server.call(**args)
      end
    end

    context "with code reloading enabled" do
      context "with default arguments" do
        it "starts server" do
          allow(subject).to receive(:exec).with("bundle exec guard -n f -i -g server -G Guardfile")

          subject.call(**args)
        end
      end

      context "without .env port" do
        it "doesn't set HANAMI_PORT" do
          allow(subject).to receive(:exec)
          subject.call(**args)

          expect(ENV.fetch("HANAMI_PORT", nil)).to be(nil)
        end

        context "with custom port CLI option" do
          let(:port) { 9000 }

          it "sets HANAMI_PORT value" do
            allow(subject).to receive(:exec)
            subject.call(**args)

            expect(ENV.fetch("HANAMI_PORT", nil)).to eq(port.to_s)
          end
        end
      end

      context "with .env port" do
        before { ENV["HANAMI_PORT"] = dotenv_port.to_s }
        let(:dotenv_port) { 9000 }

        it "respects HANAMI_PORT value" do
          allow(subject).to receive(:exec)
          subject.call(**args)

          expect(ENV.fetch("HANAMI_PORT", nil)).to eq(dotenv_port.to_s)
        end

        context "with custom port CLI option" do
          let(:port) { 18_000 }
          let(:cli_arg_port) { port }

          it "overrides HANAMI_PORT value" do
            allow(subject).to receive(:exec)
            subject.call(**args)

            expect(ENV.fetch("HANAMI_PORT", nil)).to eq(cli_arg_port.to_s)
          end
        end
      end
    end

    context "with code reloading disabled" do
      subject { described_class.new(server: server) }
      let(:code_reloading) { false }
      let(:server) { proc { |*| } }

      it "starts original hanami-cli server" do
        allow(server).to receive(:call)

        subject.call(**args)
      end

      context "without .env port" do
        it "doesn't set HANAMI_PORT" do
          allow(server).to receive(:call)
          subject.call(**args)

          expect(ENV.fetch("HANAMI_PORT", nil)).to be(nil)
        end

        context "with custom port CLI option" do
          let(:port) { 9000 }

          it "doesn't set HANAMI_PORT" do
            allow(server).to receive(:call)
            subject.call(**args)

            expect(ENV.fetch("HANAMI_PORT", nil)).to be(nil)
          end
        end
      end

      context "with .env port" do
        before { ENV["HANAMI_PORT"] = dotenv_port.to_s }
        let(:dotenv_port) { 9000 }

        it "respects HANAMI_PORT value" do
          allow(server).to receive(:call)
          subject.call(**args)

          expect(ENV.fetch("HANAMI_PORT", nil)).to eq(dotenv_port.to_s)
        end

        context "with custom port CLI option" do
          let(:port) { 18_000 }
          let(:cli_arg_port) { port }

          it "respects HANAMI_PORT value" do
            allow(server).to receive(:call)
            subject.call(**args)

            expect(ENV.fetch("HANAMI_PORT", nil)).to eq(dotenv_port.to_s)
          end
        end
      end
    end

    context "with custom Guardfile path" do
      let(:guardfile) { Pathname.new(Dir.pwd).join("Guardfile") }

      it "uses given value" do
        allow(subject).to receive(:exec).with("bundle exec guard -n f -i -g server -G #{guardfile}")

        subject.call(**args)
      end
    end
  end
end
