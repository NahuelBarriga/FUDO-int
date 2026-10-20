# frozen_string_literal: true

require_relative "../errors"
require_relative "../../lib/access_token"

module Http
  class Authenticated
    USER_ID_KEY = "auth.user_id"
    BEARER = /\ABearer (\S+)\z/i

    def initialize(app)
      @app = app
    end

    def call(env)
      env[USER_ID_KEY] = user_id_from(env)

      status, headers, body = @app.call(env)
      headers["cache-control"] = "no-store"
      [status, headers, body]
    end

    private

    def user_id_from(env)
      match = BEARER.match(env["HTTP_AUTHORIZATION"].to_s)
      raise Errors::Unauthorized, "Missing bearer token" unless match

      AccessToken.verify(match[1])
    rescue AccessToken::Invalid
      raise Errors::Unauthorized, "Invalid or expired token"
    end
  end
end
