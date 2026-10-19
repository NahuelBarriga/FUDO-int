# frozen_string_literal: true

require_relative "../../errors"
require_relative "../../../lib/json_response"
require_relative "../../../lib/router"
require_relative "../../../lib/middleware/request_id"

module Http
  module Middleware
    class ErrorHandler
      STATUS_BY_ERROR = {
        Errors::InvalidJson => 400,
        Errors::InvalidBody => 400,
        Errors::NotFound => 404
      }.freeze  

      def initialize(app)
        @app = app
        @logger = logger
      end

      def call(env)
        @app.call(env)
      rescue Router::NotFound
        render(404, "not_found", "Not found")
      rescue Router::MethodNotAllowed => e
        render( 405, "method_not_allowed", "Method not allowed", { "allow" => e.allowed_methods.join(", ") })
      rescue Errors::AppError => e
        render(status_for(e), e.code, e.message)
      rescue StandardError => e
        log_unexpected(env, e)
        render(500, "internal_error", "Internal server error")
      end

      private

      def status_for(error)
        match = STATUS_BY_ERROR.find { |klass, _status| error.is_a?(klass) }
        match ? match.last : 500
      end

      def log_unexpected(env, error)
        @logger.error({
          request_id: env[Middleware::RequestId::ENV_KEY],
          error: error.class.name,
          message: error.message,
          backtrace: error.backtrace&.first(5)
        })
      end

      def render(status, code, message, headers = {})
        JsonResponse.build(status, { error: { code: code, message: message } }, headers)
      end
    end
  end
end
