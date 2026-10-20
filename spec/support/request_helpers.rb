# frozen_string_literal: true

require "json"
require "rack/builder"
require_relative "../../lib/access_token"

# Ayudas para los tests de request: la app completa (config.ru) y atajos
# para mandar JSON y autenticarse.
module RequestHelpers
  include Rack::Test::Methods

  APP = Rack::Builder.parse_file(File.expand_path("../../config.ru", __dir__))

  def app
    APP
  end

  def json_body
    JSON.parse(last_response.body)
  end

  def post_json(path, body, headers = {})
    post path, JSON.generate(body), { "CONTENT_TYPE" => "application/json" }.merge(headers)
  end

  def auth_headers(user, now: Time.now)
    { "HTTP_AUTHORIZATION" => "Bearer #{AccessToken.issue(user.id, now: now)}" }
  end
end
