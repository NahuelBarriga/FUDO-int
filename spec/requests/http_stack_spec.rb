# frozen_string_literal: true

require_relative "../../lib/uuid"

# Comportamiento transversal de la pila de middlewares (D26), visto desde HTTP.
# Usa /AUTHORS porque no depende de la base, de Redis ni de un token.
RSpec.describe "HTTP middleware stack", type: :request do
  it "returns 404 as JSON for unknown routes" do
    get "/does-not-exist"

    expect(last_response.status).to eq(404)
    expect(last_response.headers["content-type"]).to eq("application/json")
    expect(json_body["error"]["code"]).to eq("not_found")
  end

  it "does not match routes by prefix" do
    get "/AUTHORS/extra"

    expect(last_response.status).to eq(404)
  end

  it "adds a request id to every response, including errors" do
    get "/does-not-exist"

    expect(Uuid.valid?(last_response.headers["x-request-id"])).to be(true)
  end

  it "keeps a valid request id sent by the client" do
    get "/AUTHORS", {}, { "HTTP_X_REQUEST_ID" => "client-id-123" }

    expect(last_response.headers["x-request-id"]).to eq("client-id-123")
  end

  it "compresses the response when the client asks for gzip (D7)" do
    get "/AUTHORS", {}, { "HTTP_ACCEPT_ENCODING" => "gzip" }

    expect(last_response.headers["content-encoding"]).to eq("gzip")
    expect(last_response.headers["vary"]).to include("Accept-Encoding")
  end

  it "does not compress when the client does not ask for it" do
    get "/AUTHORS"

    expect(last_response.headers["content-encoding"]).to be_nil
  end
end
