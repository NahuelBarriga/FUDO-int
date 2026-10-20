# frozen_string_literal: true

require "json"
require "stringio"
require_relative "../../../lib/json_logger"
require_relative "../../../lib/middleware/request_logger"

RSpec.describe Middleware::RequestLogger, :aggregate_failures do
  let(:output) { StringIO.new }
  let(:middleware) { described_class.new(->(_env) { [201, {}, []] }, JsonLogger.build(output)) }

  it "logs one JSON line per request with its main data" do
    middleware.call("REQUEST_METHOD" => "POST", "PATH_INFO" => "/products", "request_id" => "req-1")
    entry = JSON.parse(output.string)

    expect(entry).to include(
      "level" => "INFO",
      "request_id" => "req-1",
      "method" => "POST",
      "path" => "/products",
      "status" => 201
    )
    expect(entry["duration_ms"]).to be_a(Numeric)
  end

  it "returns the inner response untouched" do
    expect(middleware.call("REQUEST_METHOD" => "GET", "PATH_INFO" => "/")).to eq([201, {}, []])
  end
end
