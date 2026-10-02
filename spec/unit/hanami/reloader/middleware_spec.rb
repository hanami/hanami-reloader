# frozen_string_literal: true

RSpec.describe Hanami::Reloader::Middleware do
  subject(:middleware) do
    described_class.new(inner, file_checker: file_checker, slice: slice, out: out)
  end

  let(:inner) { ->(_env) { [200, {}, ["ok"]] } }
  let(:out) { StringIO.new }
  let(:env) { {"PATH_INFO" => "/"} }

  # Stands in for a slice class (e.g. `Hanami.app`), which responds to `reload` and `config`.
  let(:slice) { double("slice", reload: true, config: config) }
  let(:config) { double("config", render_detailed_errors: true) }

  let(:file_checker) do
    instance_double(
      Hanami::Reloader::FileChecker,
      updated?: updated, restart_required: restart_required, commit!: true, failed!: true
    )
  end
  let(:updated) { false }
  let(:restart_required) { [] }

  # hanami-webconsole is not in this gem's bundle, so unless a spec says otherwise the reloader
  # has nothing to render an error with.
  before { allow(Hanami).to receive(:bundled?).with("hanami-webconsole").and_return(false) }

  it "passes the request through" do
    status, headers, body = middleware.call(env)

    expect(status).to eq(200)
    expect(headers).to eq({})
    expect(read(body)).to eq("ok")
  end

  context "when nothing has changed" do
    it "does not reload" do
      expect(slice).not_to receive(:reload)

      middleware.call(env)
    end
  end

  context "when a watched file has changed" do
    let(:updated) { true }

    it "reloads before dispatching" do
      order = []
      allow(slice).to receive(:reload) { order << :reload }
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
      before { allow(slice).to receive(:reload).and_raise(SyntaxError, "unexpected end") }

      it "lets the error surface" do
        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end

      it "does not dispatch into the half-unloaded app" do
        expect(inner).not_to receive(:call)

        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end

      it "does not commit, so the fixed file is still picked up" do
        expect(file_checker).not_to receive(:commit!)

        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end

      it "tells the file_checker the attempt failed, so it is not retried every request" do
        expect(file_checker).to receive(:failed!)

        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end
    end
  end

  describe "rendering a failed reload" do
    # Stands in for a real checker rather than answering `updated?` the same way forever: the
    # change stays outstanding until it is committed, and a failed attempt is not reported again
    # until the files change.
    let(:file_checker) do
      Class.new do
        attr_reader :checks

        def initialize
          @changed = true
          @failed = false
          @checks = 0
        end

        def updated? = @changed && !@failed

        def commit! = tap { @changed = false; @failed = false }

        def failed! = tap { @failed = true }

        def restart_required
          @checks += 1
          []
        end

        # The developer saves a fix.
        def touch! = tap { @changed = true; @failed = false }
      end.new
    end

    before { allow(slice).to receive(:reload).and_raise(SyntaxError, "unexpected end") }

    context "when webconsole is not available" do
      it "re-raises, as the reloader has always done" do
        expect { middleware.call(env) }.to raise_error(SyntaxError, "unexpected end")
      end
    end

    context "when webconsole is available" do
      # Stands in for `Hanami::Webconsole::Middleware`: renders whatever the app below it raises,
      # and answers its own console endpoints without dispatching at all. Reporting how many pages
      # it has rendered is how a spec can tell it is still the same instance.
      let(:webconsole_class) do
        Class.new do
          attr_reader :app, :config, :rendered

          def initialize(app, config)
            @app = app
            @config = config
            @rendered = []
          end

          def call(env)
            return [200, {}, ["console for #{@rendered.length} page(s)"]] if console?(env)

            @app.call(env)
          rescue Exception => exception # rubocop:disable Lint/RescueException
            @rendered << exception
            [500, {}, ["rendered #{exception.class}: #{exception.message}"]]
          end

          private

          def console?(env)
            env["PATH_INFO"].to_s.start_with?("/_hanami/webconsole")
          end
        end
      end

      before do
        allow(Hanami).to receive(:bundled?).with("hanami-webconsole").and_return(true)

        stub_const("Hanami::Webconsole", Module.new)
        stub_const("Hanami::Webconsole::MOUNT_PATH", "/_hanami/webconsole")
        stub_const("Hanami::Webconsole::Middleware", webconsole_class)
      end

      it "renders the error instead of letting it reach the server" do
        status, _headers, body = middleware.call(env)

        expect(status).to eq(500)
        expect(read(body)).to eq("rendered SyntaxError: unexpected end")
      end

      it "does not dispatch into the half-unloaded app" do
        expect(inner).not_to receive(:call)

        middleware.call(env)
      end

      it "keeps rendering it while the file is unchanged, without retrying the reload" do
        middleware.call(env)

        expect(slice).to receive(:reload).never

        status, _headers, body = middleware.call(env)

        expect(status).to eq(500)
        expect(read(body)).to eq("rendered SyntaxError: unexpected end")
      end

      it "retries once the file changes again, and serves the app when the reload succeeds" do
        middleware.call(env)

        allow(slice).to receive(:reload).and_return(true)
        file_checker.touch!

        status, _headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(read(body)).to eq("ok")
      end

      it "does not render when the app has detailed errors turned off" do
        allow(config).to receive(:render_detailed_errors).and_return(false)

        expect { middleware.call(env) }.to raise_error(SyntaxError)
      end

      context "when webconsole raises while it is being built" do
        before do
          allow(webconsole_class).to receive(:new).and_raise(RuntimeError, "webconsole broke")
        end

        it "lets the reload error reach the server, not the webconsole error" do
          expect { middleware.call(env) }.to raise_error(SyntaxError, "unexpected end")
        end

        it "logs why the error could not be rendered" do
          expect { middleware.call(env) }.to raise_error(SyntaxError)

          expect(out.string).to include(
            "[hanami] Could not render the reload error with hanami-webconsole " \
            "(RuntimeError: webconsole broke)"
          )
        end

        it "does not retry the reload while the file is unchanged" do
          expect { middleware.call(env) }.to raise_error(SyntaxError)

          expect(slice).to receive(:reload).never

          expect { middleware.call(env) }.to raise_error(SyntaxError)
        end
      end

      describe "console requests" do
        let(:console_env) { {"PATH_INFO" => "/_hanami/webconsole/0-abc/eval"} }

        it "reach the webconsole that rendered the page" do
          middleware.call(env)

          _status, _headers, body = middleware.call(console_env)

          # One page rendered means this is the same instance that holds it.
          expect(read(body)).to eq("console for 1 page(s)")
        end

        it "do not attempt a reload" do
          middleware.call(env)
          checks = file_checker.checks

          expect(slice).to receive(:reload).never

          middleware.call(console_env)

          expect(file_checker.checks).to eq(checks)
        end

        it "are dispatched to the app as usual when no reload is failing" do
          file_checker.commit!

          _status, _headers, body = middleware.call(console_env)

          expect(read(body)).to eq("ok")
        end
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
      status, _headers, body = middleware.call(env)

      expect(status).to eq(200)
      expect(read(body)).to eq("ok")
    end
  end

  describe "excluding reloads from in-flight requests" do
    it "wraps the body so the request is not over until the body is closed" do
      _, _, body = middleware.call(env)

      expect(body).to be_a(Rack::BodyProxy)
      expect(body).not_to be_closed

      body.close

      expect(body).to be_closed
    end

    it "waits for an open response body before reloading" do
      # First request: nothing has changed yet, so it just dispatches. Its body is left open, as it
      # would be while a server is still streaming the response.
      _, _, open_body = middleware.call(env)

      # Now a change lands, and a second request arrives wanting to reload.
      reloaded = Queue.new
      allow(file_checker).to receive(:updated?).and_return(true)
      allow(slice).to receive(:reload) { reloaded << :reloaded }

      second = Thread.new { read(middleware.call(env)[2]) }

      # The reload cannot start while the first body still holds a read lock.
      expect { reloaded.pop(true) }.to raise_error(ThreadError)

      open_body.close
      second.join

      expect(reloaded.size).to eq(1)
    end

    context "when an open response outlasts the reload wait" do
      subject(:middleware) do
        described_class.new(
          inner, file_checker: file_checker, slice: slice, out: out, reload_wait: 0.1
        )
      end

      # Left open, as a streamed response would be.
      let!(:open_body) { middleware.call(env)[2] }

      before { allow(file_checker).to receive(:updated?).and_return(true) }

      it "puts the reload off and serves the request with the current code" do
        expect(slice).not_to receive(:reload)
        expect(file_checker).not_to receive(:commit!)

        status, _headers, body = middleware.call(env)

        expect(status).to eq(200)
        expect(read(body)).to eq("ok")
      end

      it "says why the change has not been applied" do
        read(middleware.call(env)[2])

        expect(out.string).to include("[hanami] Waiting for 1 open response to finish before reloading")
      end

      it "does not wait or warn again on later requests while the response is still open" do
        read(middleware.call(env)[2])

        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        read(middleware.call(env)[2])
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        expect(elapsed).to be < 0.05
        expect(out.string.scan("Waiting for").length).to eq(1)
      end

      it "reloads on the next request once the response has closed" do
        read(middleware.call(env)[2])

        open_body.close
        expect(slice).to receive(:reload)

        read(middleware.call(env)[2])
      end

      it "waits again the next time a reload is put off" do
        read(middleware.call(env)[2])
        open_body.close
        read(middleware.call(env)[2])

        # A new change, with a new response held open.
        _, _, another_open_body = middleware.call(env)
        read(middleware.call(env)[2])

        expect(out.string.scan("Waiting for").length).to eq(2)
      ensure
        another_open_body&.close
      end
    end

    it "releases the read lock when the app raises" do
      calls = 0
      app = described_class.new(
        ->(_env) {
          calls += 1
          raise "boom" if calls == 1

          [200, {}, ["ok"]]
        },
        file_checker: file_checker, slice: slice, out: out
      )

      expect { app.call(env) }.to raise_error("boom")

      # The lock would still be held if the failed dispatch had not released it, and this reload
      # would be put off.
      allow(file_checker).to receive(:updated?).and_return(true)
      expect(slice).to receive(:reload)

      read(app.call(env)[2])
    end
  end

  context "with concurrent requests" do
    let(:updated) { true }

    it "reloads only once" do
      reloads = 0
      committed = false
      mutex = Mutex.new

      allow(slice).to receive(:reload) { mutex.synchronize { reloads += 1 } }

      # Stands in for a real checker: the change stays outstanding until it is committed.
      allow(file_checker).to receive(:updated?) { !committed }
      allow(file_checker).to receive(:commit!) { committed = true }

      app = described_class.new(inner, file_checker: file_checker, slice: slice, out: out)
      4.times.map { Thread.new { read(app.call(env)[2]) } }.each(&:join)

      expect(reloads).to eq(1)
    end

    it "does not dispatch a request into an app whose reload failed after it checked for changes" do
      changed = false
      allow(file_checker).to receive(:updated?) { changed }
      allow(slice).to receive(:reload).and_raise(SyntaxError, "unexpected end")

      # Hold the first request after it has checked for changes, just before it dispatches.
      checked = Queue.new
      resume = Queue.new
      paused = false
      allow(middleware).to receive(:dispatch).and_wrap_original do |original, *args|
        unless paused
          paused = true
          checked << true
          resume.pop
        end

        original.call(*args)
      end

      expect(inner).not_to receive(:call)

      first = Thread.new do
        Thread.current.report_on_exception = false
        middleware.call(env)
      end
      checked.pop

      # A change lands, and a second request reloads it and fails, while the first request is
      # still on its way to dispatch.
      changed = true
      expect { middleware.call(env) }.to raise_error(SyntaxError)

      resume << true
      expect { first.value }.to raise_error(SyntaxError, "unexpected end")
    end
  end
end
