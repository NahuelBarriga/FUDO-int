# frozen_string_literal: true

RSpec.describe "Rate limiting (D56)", :aggregate_failures, type: :request do
  def login(username, ip)
    post_json "/auth/login", { username: username, password: "incorrecta" }, { "REMOTE_ADDR" => ip }
  end

  def register(username, ip)
    post_json "/auth/register", { username: username, password: "supersecreta" }, { "REMOTE_ADDR" => ip }
  end

  it "limits login attempts per IP and answers 429 with Retry-After" do
    10.times { |i| login("user#{i}", "10.0.0.1") }
    expect(last_response.status).to eq(401)

    login("another", "10.0.0.1")
    expect(last_response.status).to eq(429)
    expect(json_body["error"]["code"]).to eq("rate_limited")
    expect(last_response.headers["retry-after"].to_i).to be_between(1, 60)
  end

  it "limits login attempts per username across different IPs, ignoring case" do
    5.times { |i| login("nahuel", "10.0.1.#{i}") }
    expect(last_response.status).to eq(401)

    login("NAHUEL", "10.0.1.99")
    expect(last_response.status).to eq(429)
  end

  it "keeps the login body readable after counting by username" do
    create_user(username: "nahuel", password: "supersecreta")
    post_json "/auth/login", { username: "nahuel", password: "supersecreta" }

    expect(last_response.status).to eq(200)
  end

  it "limits registrations per IP" do
    10.times { |i| register("user_#{i}", "10.0.2.1") }
    expect(last_response.status).to eq(201)

    register("user_extra", "10.0.2.1")
    expect(last_response.status).to eq(429)
  end

  it "does not limit other clients" do
    10.times { |i| login("user#{i}", "10.0.3.1") }
    login("someone", "10.0.3.2")

    expect(last_response.status).to eq(401)
  end
end
