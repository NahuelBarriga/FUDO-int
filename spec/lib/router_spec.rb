# frozen_string_literal: true

require_relative "../../lib/router"

RSpec.describe Router do
  let(:ok_app) { ->(_env) { [200, {}, ["ok"]] } }

  let(:router) do
    router = described_class.new
    router.get "/items", ok_app
    router.post "/items", ok_app
    router.get "/items/:id", ok_app
    router.get "/file.txt", ok_app
    router
  end

  def env_for(verb, path)
    { "REQUEST_METHOD" => verb, "PATH_INFO" => path }
  end

  it "dispatches a request to the matching route" do
    status, _headers, _body = router.call(env_for("GET", "/items"))
    expect(status).to eq(200)
  end

  it "extracts path parameters into the env" do
    env = env_for("GET", "/items/42")
    router.call(env)
    expect(env[Router::PARAMS_KEY]).to eq("id" => "42")
  end

  it "serves HEAD requests with the GET route" do
    status, _headers, _body = router.call(env_for("HEAD", "/items"))
    expect(status).to eq(200)
  end

  it "raises NotFound for an unknown path" do
    expect { router.call(env_for("GET", "/nope")) }.to raise_error(Router::NotFound)
  end

  it "does not match by prefix" do
    expect { router.call(env_for("GET", "/items/42/extra")) }.to raise_error(Router::NotFound)
  end

  it "treats dots in a route literally" do
    expect { router.call(env_for("GET", "/fileXtxt")) }.to raise_error(Router::NotFound)
  end

  it "raises MethodNotAllowed with the allowed methods" do
    expect { router.call(env_for("DELETE", "/items")) }
      .to raise_error(Router::MethodNotAllowed) { |error|
        expect(error.allowed_methods).to contain_exactly("GET", "POST", "HEAD")
      }
  end
end
