# frozen_string_literal: true

require "securerandom"

RSpec.describe "Products", :aggregate_failures, type: :request do
  let(:user) { create_user }
  let(:headers) { auth_headers(user) }

  describe "POST /products" do
    it "accepts the request without creating the product yet (202, D46)" do
      post_json "/products", { name: "Coca" }, headers

      expect(last_response.status).to eq(202)
      expect(json_body).to include("name" => "Coca", "status" => "pending", "product_id" => nil, "error" => nil)
      expect(last_response.headers["location"]).to eq("/product_requests/#{json_body["id"]}")
      expect(last_response.headers["retry-after"]).to eq("5")
      expect(Jobs::CreateProduct.jobs.size).to eq(1)
      expect(Models::Product.where(user_id: user.id).count).to eq(0)
    end

    it "returns 409 when the user already has a product with that name" do
      create_product(user: user, name: "Coca")
      post_json "/products", { name: "coca" }, headers

      expect(last_response.status).to eq(409)
      expect(json_body["error"]["code"]).to eq("name_taken")
    end

    it "returns 422 for a blank name" do
      post_json "/products", { name: "   " }, headers

      expect(last_response.status).to eq(422)
    end

    it "returns 400 for a name that is not a string" do
      post_json "/products", { name: 123 }, headers

      expect(last_response.status).to eq(400)
      expect(json_body["error"]["code"]).to eq("invalid_body")
    end

    it "returns 401 without a token" do
      post_json "/products", { name: "Coca" }

      expect(last_response.status).to eq(401)
    end

    it "returns 503 when the job cannot be enqueued (dual write)" do
      allow(Jobs::CreateProduct).to receive(:perform_in).and_raise(RedisClient::CannotConnectError)
      post_json "/products", { name: "Coca" }, headers

      expect(last_response.status).to eq(503)
      expect(json_body["error"]["code"]).to eq("service_unavailable")
    end
  end

  describe "asynchronous creation (RF-05)" do
    it "makes the product visible only after the job runs" do
      post_json "/products", { name: "Coca" }, headers
      get "/products", {}, headers
      expect(json_body["data"]).to be_empty

      Jobs::CreateProduct.drain

      get "/products", {}, headers
      expect(json_body["data"].map { |product| product["name"] }).to eq(["Coca"])
    end
  end

  describe "GET /products" do
    before do
      %w[A B C].each { |name| create_product(user: user, name: name) }
      create_product(user: create_user, name: "Someone else's")
    end

    it "lists only the user's products, in creation order, with pagination meta" do
      get "/products", {}, headers

      expect(last_response.status).to eq(200)
      expect(json_body["data"].map { |product| product["name"] }).to eq(%w[A B C])
      expect(json_body["meta"]).to eq("limit" => 20, "offset" => 0, "total" => 3)
      expect(last_response.headers["cache-control"]).to eq("no-store")
    end

    it "paginates with limit and offset at the database level" do
      get "/products?limit=2&offset=1", {}, headers

      expect(json_body["data"].map { |product| product["name"] }).to eq(%w[B C])
      expect(json_body["meta"]).to eq("limit" => 2, "offset" => 1, "total" => 3)
    end

    %w[limit=0 limit=101 limit=abc limit=2.5 offset=-1 limit[]=1].each do |query|
      it "returns 422 for ?#{query}" do
        get "/products?#{query}", {}, headers

        expect(last_response.status).to eq(422)
        expect(json_body["error"]["code"]).to eq("validation_failed")
      end
    end

    it "rejects other methods with 405 and the allowed ones" do
      delete "/products", {}, headers

      expect(last_response.status).to eq(405)
      expect(last_response.headers["allow"].split(", ")).to contain_exactly("GET", "POST", "HEAD")
    end
  end

  describe "GET /products/:id" do
    let(:product) { create_product(user: user, name: "Coca") }

    it "returns a product of the user" do
      get "/products/#{product.id}", {}, headers

      expect(last_response.status).to eq(200)
      expect(json_body).to include("id" => product.id, "name" => "Coca")
    end

    it "returns 404 for a product of another user (RN-06)" do
      get "/products/#{product.id}", {}, auth_headers(create_user)

      expect(last_response.status).to eq(404)
    end

    it "returns 404 for an id that does not exist" do
      get "/products/#{SecureRandom.uuid}", {}, headers

      expect(last_response.status).to eq(404)
    end

    it "returns 404, not 500, for a malformed id" do
      get "/products/abc", {}, headers

      expect(last_response.status).to eq(404)
    end
  end
end
