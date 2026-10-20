# frozen_string_literal: true

require_relative "../../../lib/middleware/request_id"
require_relative "../../../lib/uuid"

RSpec.describe Middleware::RequestId, :aggregate_failures do
  let(:middleware) { described_class.new(->(_env) { [200, {}, []] }) }

  def call_with(env = {})
    _status, headers, _body = middleware.call(env)
    [env, headers]
  end

  it "generates a UUID when the client sends none" do
    env, headers = call_with

    expect(Uuid.valid?(headers["x-request-id"])).to be(true)
    expect(env["request_id"]).to eq(headers["x-request-id"])
  end

  it "reuses a valid id sent by the client" do
    _env, headers = call_with("HTTP_X_REQUEST_ID" => "client-id_123")

    expect(headers["x-request-id"]).to eq("client-id_123")
  end

  ["<script>", "with space", "a" * 65].each do |invalid_id|
    it "replaces the invalid id #{invalid_id[0, 20].inspect}" do
      _env, headers = call_with("HTTP_X_REQUEST_ID" => invalid_id)

      expect(Uuid.valid?(headers["x-request-id"])).to be(true)
    end
  end
end
