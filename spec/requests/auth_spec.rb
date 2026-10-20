# frozen_string_literal: true

RSpec.describe "Authentication", type: :request do
  describe "POST /auth/register" do
    it "creates a user and never returns the password digest" do
      post_json "/auth/register", { username: "nahuel", password: "supersecreta" }

      expect(last_response.status).to eq(201)
      expect(json_body.keys).to contain_exactly("id", "username", "created_at")
      expect(json_body["username"]).to eq("nahuel")
    end

    it "returns 409 when the username is taken, ignoring case" do
      create_user(username: "nahuel")
      post_json "/auth/register", { username: "NAHUEL", password: "supersecreta" }

      expect(last_response.status).to eq(409)
      expect(json_body["error"]["code"]).to eq("username_taken")
    end

    it "returns 422 for an invalid username" do
      post_json "/auth/register", { username: "ab", password: "supersecreta" }

      expect(last_response.status).to eq(422)
      expect(json_body["error"]["code"]).to eq("validation_failed")
    end

    it "returns 400 for malformed JSON" do
      post "/auth/register", "{nope", { "CONTENT_TYPE" => "application/json" }

      expect(last_response.status).to eq(400)
      expect(json_body["error"]["code"]).to eq("invalid_json")
    end

    it "returns 400 for fields outside the structure (strict, D31)" do
      post_json "/auth/register", { username: "nahuel", password: "supersecreta", admin: true }

      expect(last_response.status).to eq(400)
      expect(json_body["error"]["code"]).to eq("invalid_body")
    end
  end

  describe "POST /auth/login" do
    before { create_user(username: "nahuel", password: "supersecreta") }

    it "returns a bearer token that authenticates the user" do
      post_json "/auth/login", { username: "nahuel", password: "supersecreta" }

      expect(last_response.status).to eq(200)
      expect(json_body).to include("token_type" => "Bearer", "expires_in" => AccessToken::TTL_SECONDS)

      get "/auth/me", {}, { "HTTP_AUTHORIZATION" => "Bearer #{json_body["access_token"]}" }
      expect(json_body["username"]).to eq("nahuel")
    end

    it "returns 401 for a wrong password" do
      post_json "/auth/login", { username: "nahuel", password: "incorrecta" }

      expect(last_response.status).to eq(401)
      expect(json_body["error"]["code"]).to eq("invalid_credentials")
    end

    it "answers an unknown user exactly like a wrong password (RN-08)" do
      post_json "/auth/login", { username: "nahuel", password: "incorrecta" }
      wrong_password = [last_response.status, last_response.body]

      post_json "/auth/login", { username: "noexiste", password: "incorrecta" }

      expect([last_response.status, last_response.body]).to eq(wrong_password)
    end
  end

  describe "GET /auth/me" do
    let(:user) { create_user(username: "nahuel") }

    it "returns the current user and is not cacheable (D51)" do
      get "/auth/me", {}, auth_headers(user)

      expect(last_response.status).to eq(200)
      expect(json_body).to include("id" => user.id, "username" => "nahuel")
      expect(json_body).not_to have_key("password_digest")
      expect(last_response.headers["cache-control"]).to eq("no-store")
    end

    it "returns 401 without a token" do
      get "/auth/me"

      expect(last_response.status).to eq(401)
      expect(json_body["error"]["message"]).to eq("Missing bearer token")
    end

    it "returns 401 for an invalid token" do
      get "/auth/me", {}, { "HTTP_AUTHORIZATION" => "Bearer garbage" }

      expect(last_response.status).to eq(401)
      expect(json_body["error"]["code"]).to eq("unauthorized")
    end

    it "returns 401 for an expired token" do
      get "/auth/me", {}, auth_headers(user, now: Time.now - AccessToken::TTL_SECONDS - 1)

      expect(last_response.status).to eq(401)
    end

    it "returns 401 when the user no longer exists" do
      headers = auth_headers(user)
      user.delete
      get "/auth/me", {}, headers

      expect(last_response.status).to eq(401)
    end
  end
end
