# frozen_string_literal: true

RSpec.describe "GET /AUTHORS", type: :request do
  let(:authors_file) { File.expand_path("../../AUTHORS", __dir__) }

  def etag
    get "/AUTHORS"
    last_response.headers["etag"]
  end

  it "returns the author as plain text with cache headers (D50)" do
    get "/AUTHORS"

    expect(last_response.status).to eq(200)
    expect(last_response.body).to eq(File.read(authors_file))
    expect(last_response.headers["content-type"]).to eq("text/plain; charset=utf-8")
    expect(last_response.headers["cache-control"]).to eq("public, max-age=86400")
    expect(last_response.headers["etag"]).to start_with('W/"')
    expect(last_response.headers["last-modified"]).not_to be_nil
  end

  it "is public: no token needed" do
    get "/AUTHORS"

    expect(last_response.status).to eq(200)
  end

  it "answers HEAD with the headers and no body" do
    head "/AUTHORS"

    expect(last_response.status).to eq(200)
    expect(last_response.headers["etag"]).to start_with('W/"')
    expect(last_response.body).to be_empty
  end

  it "returns 304 without body when the ETag matches" do
    current = etag
    get "/AUTHORS", {}, { "HTTP_IF_NONE_MATCH" => current }

    expect(last_response.status).to eq(304)
    expect(last_response.body).to be_empty
    expect(last_response.headers["cache-control"]).to eq("public, max-age=86400")
  end

  it "uses weak comparison: the ETag without W/ also matches" do
    strong = etag.delete_prefix("W/")
    get "/AUTHORS", {}, { "HTTP_IF_NONE_MATCH" => strong }

    expect(last_response.status).to eq(304)
  end

  it "returns 304 for If-None-Match: *" do
    get "/AUTHORS", {}, { "HTTP_IF_NONE_MATCH" => "*" }

    expect(last_response.status).to eq(304)
  end

  it "returns 200 when the ETag does not match" do
    get "/AUTHORS", {}, { "HTTP_IF_NONE_MATCH" => 'W/"other"' }

    expect(last_response.status).to eq(200)
  end

  it "returns 304 when the file was not modified since the given date" do
    get "/AUTHORS"
    last_modified = last_response.headers["last-modified"]
    get "/AUTHORS", {}, { "HTTP_IF_MODIFIED_SINCE" => last_modified }

    expect(last_response.status).to eq(304)
  end

  it "returns 200 when the given date is older than the file" do
    get "/AUTHORS", {}, { "HTTP_IF_MODIFIED_SINCE" => "Mon, 01 Jan 2024 00:00:00 GMT" }

    expect(last_response.status).to eq(200)
  end

  it "ignores a malformed date" do
    get "/AUTHORS", {}, { "HTTP_IF_MODIFIED_SINCE" => "not a date" }

    expect(last_response.status).to eq(200)
  end

  it "rejects other methods with 405 and Allow: GET, HEAD" do
    post "/AUTHORS"

    expect(last_response.status).to eq(405)
    expect(last_response.headers["allow"].split(", ")).to contain_exactly("GET", "HEAD")
  end
end
