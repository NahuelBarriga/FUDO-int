# frozen_string_literal: true

require "json"
require "stringio"
require_relative "../../../../app/http/middleware/error_handler"
require_relative "../../../../lib/json_logger"

RSpec.describe Http::Middleware::ErrorHandler, :aggregate_failures do
  let(:log_output) { StringIO.new }
  let(:logger) { JsonLogger.build(log_output) }

  def call_raising(error)
    described_class.new(->(_env) { raise error }, logger).call({ "request_id" => "req-1" })
  end

  def error_of(response)
    JSON.parse(response[2].first).fetch("error")
  end

  it "passes successful responses through untouched" do
    response = [200, {}, ["ok"]]

    expect(described_class.new(->(_env) { response }, logger).call({})).to eq(response)
  end

  {
    Errors::InvalidJson => 400,
    Errors::InvalidBody => 400,
    Errors::InvalidCredentials => 401,
    Errors::Unauthorized => 401,
    Errors::NotFound => 404,
    Errors::UsernameTaken => 409,
    Errors::NameTaken => 409,
    Errors::ValidationFailed => 422,
    Errors::ServiceUnavailable => 503
  }.each do |error_class, status|
    it "maps #{error_class} to #{status} with its code" do
      error = error_class.new
      response = call_raising(error)

      expect(response[0]).to eq(status)
      expect(error_of(response)).to eq("code" => error.code, "message" => error.message)
    end
  end

  it "maps Router::NotFound to 404" do
    response = call_raising(Router::NotFound.new)

    expect(response[0]).to eq(404)
    expect(error_of(response)["code"]).to eq("not_found")
  end

  it "maps Router::MethodNotAllowed to 405 with an Allow header" do
    response = call_raising(Router::MethodNotAllowed.new(%w[GET POST]))

    expect(response[0]).to eq(405)
    expect(response[1]["allow"]).to eq("GET, POST")
  end

  it "hides unexpected errors behind a generic 500" do
    response = call_raising(RuntimeError.new("secret internal detail"))

    expect(response[0]).to eq(500)
    expect(error_of(response)).to eq("code" => "internal_error", "message" => "Internal server error")
    expect(response[2].first).not_to include("secret internal detail")
  end

  it "logs unexpected errors with the request id, only in the log" do
    call_raising(RuntimeError.new("secret internal detail"))
    entry = JSON.parse(log_output.string)

    expect(entry).to include(
      "level" => "ERROR",
      "request_id" => "req-1",
      "error" => "RuntimeError",
      "message" => "secret internal detail"
    )
  end
end
