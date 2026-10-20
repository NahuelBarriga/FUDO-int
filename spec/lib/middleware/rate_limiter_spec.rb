# frozen_string_literal: true

require "json"
require "stringio"
require_relative "../../../lib/json_logger"
require_relative "../../../lib/middleware/rate_limiter"

RSpec.describe Middleware::RateLimiter, :aggregate_failures do
  let(:log_output) { StringIO.new }
  let(:logger) { JsonLogger.build(log_output) }
  let(:inner_app) { ->(_env) { [200, {}, []] } }
  let(:by_ip) do
    described_class::Rule.new(name: :test, limit: 2, period: 60, discriminator: lambda { |env|
      env["REMOTE_ADDR"]
    })
  end

  def limiter(store: described_class::MemoryStore.new, rules: [by_ip])
    described_class.new(inner_app, rules, store, logger)
  end

  # Tiempo fijo al inicio de una ventana de 60 s: los resultados no dependen del reloj.
  before { allow(Time).to receive(:now).and_return(Time.at(1_800_000_000)) }

  it "lets requests through up to the limit" do
    app = limiter

    expect(Array.new(2) { app.call("REMOTE_ADDR" => "1.1.1.1")[0] }).to eq([200, 200])
  end

  it "raises Exceeded with the seconds left in the window" do
    app = limiter
    2.times { app.call("REMOTE_ADDR" => "1.1.1.1") }

    expect { app.call("REMOTE_ADDR" => "1.1.1.1") }
      .to raise_error(described_class::Exceeded) { |error| expect(error.retry_after).to eq(60) }
  end

  it "counts each client separately" do
    app = limiter
    2.times { app.call("REMOTE_ADDR" => "1.1.1.1") }

    expect(app.call("REMOTE_ADDR" => "2.2.2.2")[0]).to eq(200)
  end

  it "skips a rule when its discriminator returns nil" do
    never = described_class::Rule.new(name: :never, limit: 0, period: 60, discriminator: ->(_env) {})

    expect(limiter(rules: [never]).call({})[0]).to eq(200)
  end

  it "lets requests through and logs a warning when the store is unavailable (fail open)" do
    store = instance_double(described_class::MemoryStore)
    allow(store).to receive(:increment).and_raise(described_class::StoreUnavailable, "down")

    expect(limiter(store: store).call("REMOTE_ADDR" => "1.1.1.1")[0]).to eq(200)
    expect(JSON.parse(log_output.string)).to include("level" => "WARN", "event" => "rate_limit_store_unavailable")
  end
end
