# frozen_string_literal: true

require "securerandom"

module Middleware
  class RequestId
    HEADER = "x-request-id"
    ENV_KEY = "request_id"
    VALID_ID = /\A[\w-]{1,64}\z/

    def initialize(app)
      @app = app
    end

    def call(env)
      id = request_id_from(env)
      env[ENV_KEY] = id

      status, headers, body = @app.call(env)
      headers[HEADER] = id
      [status, headers, body]
    end

    private

    def request_id_from(env) # reusa el request_id si es valido, sino genera uno nuevo
      incoming = env["HTTP_X_REQUEST_ID"].to_s
      VALID_ID.match?(incoming) ? incoming : SecureRandom.uuid_v7
    end
  end
end
