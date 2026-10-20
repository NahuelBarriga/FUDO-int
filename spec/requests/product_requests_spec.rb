# frozen_string_literal: true

RSpec.describe "GET /product_requests/:id", :aggregate_failures, type: :request do
  let(:user) { create_user }
  let(:headers) { auth_headers(user) }
  let(:product_request) { create_product_request(user: user, name: "Coca") }

  it "returns a pending request with Retry-After: 1" do
    get "/product_requests/#{product_request.id}", {}, headers

    expect(last_response.status).to eq(200)
    expect(json_body).to include("id" => product_request.id, "status" => "pending", "product_id" => nil)
    expect(last_response.headers["retry-after"]).to eq("1")
  end

  it "returns a completed request with its product and no Retry-After" do
    Services::FulfillProductRequest.new.call(product_request_id: product_request.id)
    get "/product_requests/#{product_request.id}", {}, headers

    expect(json_body["status"]).to eq("completed")
    expect(json_body["product_id"]).not_to be_nil
    expect(last_response.headers["retry-after"]).to be_nil
  end

  it "follows the whole flow: request -> completed -> product" do
    Services::FulfillProductRequest.new.call(product_request_id: product_request.id)
    get "/product_requests/#{product_request.id}", {}, headers
    get "/products/#{json_body["product_id"]}", {}, headers

    expect(last_response.status).to eq(200)
    expect(json_body["name"]).to eq("Coca")
  end

  it "returns 404 for a request of another user (RN-06)" do
    get "/product_requests/#{product_request.id}", {}, auth_headers(create_user)

    expect(last_response.status).to eq(404)
  end

  it "returns 404, not 500, for a malformed id" do
    get "/product_requests/abc", {}, headers

    expect(last_response.status).to eq(404)
  end

  it "returns 401 without a token" do
    get "/product_requests/#{product_request.id}"

    expect(last_response.status).to eq(401)
  end
end
