# frozen_string_literal: true

RSpec.describe Hanami::Reloader::Middleware do
  subject(:middleware) do
    described_class.new(inner, file_checker: file_checker, slice: slice, out: out)
  end

  let(:inner) { ->(_env) { [200, {}, ["ok"]] } }
  let(:out) { StringIO.new }
  let(:env) { {"PATH_INFO" => "/"} }

  # Stands in for a slice class (e.g. `Hanami.app`), which responds to `reload!`.
  let(:slice) { double("slice", reload!: true) }

  let(:file_checker) do
    instance_double(
      Hanami::Reloader::FileChecker,
      updated?: updated, restart_required: restart_required, commit!: true
    )
  end
  let(:updated) { false }
  let(:restart_required) { [] }

  it "passes the request through" do
    expect(middleware.call(env)).to eq([200, {}, ["ok"]])
  end

  context "when nothing has changed" do
    it "does not reload" do
      expect(slice).not_to receive(:reload!)

      middleware.call(env)
    end
  end

  context "when a watched file has changed" do
    let(:updated) { true }

    it "reloads before dispatching" do
      order = []
      allow(slice).to receive(:reload!) { order << :reload }
      app = described_class.new(
        ->(_env) { order << :dispatch; [200, {}, ["ok"]] },
        file_checker: file_checker, slice: slice, out: out
      )

      app.call(env)

      expect(order).to eq([:reload, :dispatch])
    end

    it "commits the file_checker so the change is not reloaded twice" do
      expect(file_checker).to receive(:commit!)

      middleware.call(env)
    end

    it "reports how long the reload took" do
      middleware.call(env)

      expect(out.string).to match(/\[hanami\] Reloaded in \d+ms/)
    end

    context "and the reload raises" do
      before { allow(slice).to receive(:reload!).and_raise(SyntaxError, "unexpected end") }

      it "lets the error surface" do
        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end

      it "does not commit, so the next request retries the reload" do
        expect(file_checker).not_to receive(:commit!)

        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end
    end
  end

  context "when a file requiring a restart has changed" do
    let(:restart_required) { ["config/app.rb"] }

    it "warns instead of silently doing nothing" do
      middleware.call(env)

      expect(out.string).to include("config/app.rb cannot be reloaded")
      expect(out.string).to include("Restart the server")
    end

    it "still serves the request" do
      expect(middleware.call(env)).to eq([200, {}, ["ok"]])
    end
  end

  context "with concurrent requests" do
    let(:updated) { true }

    it "reloads only once" do
      reloads = 0
      mutex = Mutex.new
      allow(slice).to receive(:reload!) { mutex.synchronize { reloads += 1 } }

      # After the first reload commits, the file_checker reports no further change.
      allow(file_checker).to receive(:updated?).and_return(true, false, false, false)

      app = described_class.new(inner, file_checker: file_checker, slice: slice, out: out)
      4.times.map { Thread.new { app.call(env) } }.each(&:join)

      expect(reloads).to eq(1)
    end
  end
end
