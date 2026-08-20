# frozen_string_literal: true

require "tmpdir"

RSpec.describe Hanami::Reloader::Commands::Install do
  describe "#call" do
    subject { described_class.new(fs: fs, out: out) }

    let(:fs) { Dry::Files.new }
    let(:out) { StringIO.new }
    let(:dir) { Dir.mktmpdir }

    around do |example|
      fs.chdir(dir) { example.run }
    ensure
      fs.delete_directory(dir)
    end

    context "when a Guard-based Guardfile is present" do
      before do
        fs.write("Guardfile", <<~RUBY)
          group :server do
            guard "puma", port: 2300 do
              watch(%r{^app/.*\\.rb$})
            end
          end
        RUBY
      end

      it "removes it, since reloading no longer runs through Guard" do
        subject.call({})

        expect(fs.exist?("Guardfile")).to be(false)
        expect(out.string).to include("Removed Guardfile")
      end
    end

    context "when a Guardfile is present but not ours" do
      before { fs.write("Guardfile", "guard \"rspec\" do\nend\n") }

      it "leaves it alone" do
        subject.call({})

        expect(fs.exist?("Guardfile")).to be(true)
      end
    end

    context "when no Guardfile is present" do
      it "does nothing" do
        expect { subject.call({}) }.not_to raise_error

        expect(fs.exist?("Guardfile")).to be(false)
      end
    end
  end
end
