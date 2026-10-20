# frozen_string_literal: true

require_relative "../../../../lib/middleware/rate_limiter"

RSpec.describe Middleware::RateLimiter::RedisStore, :aggregate_failures do
  let(:conn) { instance_double(RedisClient) }
  let(:pool) { instance_double(ConnectionPool) }

  before { allow(pool).to receive(:with).and_yield(conn) }

  it "increments the counter and sets its expiration only once (NX)" do
    allow(conn).to receive(:call).with("INCR", "key").and_return(3)
    allow(conn).to receive(:call).with("EXPIRE", "key", 60, "NX")

    expect(described_class.new(pool).increment("key", 60)).to eq(3)
    expect(conn).to have_received(:call).with("EXPIRE", "key", 60, "NX")
  end

  it "translates Redis errors to StoreUnavailable" do
    allow(pool).to receive(:with).and_raise(RedisClient::CannotConnectError)

    expect { described_class.new(pool).increment("key", 60) }
      .to raise_error(Middleware::RateLimiter::StoreUnavailable)
  end
end
