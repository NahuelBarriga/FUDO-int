# frozen_string_literal: true

RSpec.describe "GET /health", :aggregate_failures, type: :request do
  let(:worker_count) { 1 }

  # Redis y el worker se simulan: los tests no necesitan Redis ni Sidekiq corriendo.
  before do
    allow(Sidekiq).to receive(:redis).and_return("PONG")
    allow(Sidekiq::ProcessSet).to receive(:new)
      .and_return(instance_double(Sidekiq::ProcessSet, size: worker_count))
  end

  it "reports ok when every dependency is up" do
    get "/health"

    expect(last_response.status).to eq(200)
    expect(json_body).to eq(
      "status" => "ok",
      "checks" => { "postgres" => "up", "redis" => "up", "worker" => "up" }
    )
    expect(last_response.headers["cache-control"]).to eq("no-store")
  end

  context "when no worker is running" do
    let(:worker_count) { 0 }

    it "reports degraded but still answers 200 (D53)" do
      get "/health"

      expect(last_response.status).to eq(200)
      expect(json_body["status"]).to eq("degraded")
      expect(json_body["checks"]["worker"]).to eq("down")
    end
  end

  context "when Redis is down" do
    before do
      allow(Sidekiq).to receive(:redis).and_raise(RedisClient::CannotConnectError)
      allow(Sidekiq::ProcessSet).to receive(:new).and_raise(RedisClient::CannotConnectError)
    end

    it "reports down with 503" do
      get "/health"

      expect(last_response.status).to eq(503)
      expect(json_body["status"]).to eq("down")
      expect(json_body["checks"]).to include("redis" => "down", "worker" => "down")
    end
  end

  context "when Postgres is down" do
    before { allow(DB).to receive(:test_connection).and_raise(Sequel::DatabaseConnectionError) }

    it "reports down with 503" do
      get "/health"

      expect(last_response.status).to eq(503)
      expect(json_body["checks"]["postgres"]).to eq("down")
    end
  end
end
