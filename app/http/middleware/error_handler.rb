# frozen_string_literal: true

require_relative "../../errors"
require_relative "../../../lib/json_response"
require_relative "../../../lib/router"
require_relative "../../../lib/middleware/request_id"
require_relative "../../../lib/middleware/rate_limiter"

module Http
  module Middleware
    class ErrorHandler
      STATUS_BY_ERROR = {
        Errors::InvalidJson => 400,
        Errors::InvalidBody => 400,
        Errors::NotFound => 404,
        Errors::UsernameTaken => 409,
        Errors::ValidationFailed => 422,
        Errors::InvalidCredentials => 401,
        Errors::Unauthorized => 401,
        Errors::NameTaken => 409,
        Errors::ServiceUnavailable => 503
      }.freeze

      KNOWN_ERRORS = [
        Router::NotFound,
        Router::MethodNotAllowed,
        ::Middleware::RateLimiter::Exceeded,
        Errors::AppError
      ].freeze

      def initialize(app, logger)
        @app = app
        @logger = logger
      end

      def call(env)
        @app.call(env)
      rescue *KNOWN_ERRORS => e
        render_error(e)
      rescue StandardError => e
        log_unexpected(env, e)
        render(500, "internal_error", "Internal server error")
      end

      private

      def render_error(error)
        case error
        when Router::NotFound
          render(404, "not_found", "Not found")
        when Router::MethodNotAllowed
          render(405, "method_not_allowed", "Method not allowed", { "allow" => error.allowed_methods.join(", ") })
        when ::Middleware::RateLimiter::Exceeded
          render(429, "rate_limited", "Too many requests", { "retry-after" => error.retry_after.to_s })
        else
          render(status_for(error), error.code, error.message)
        end
      end

      def status_for(error)
        match = STATUS_BY_ERROR.find { |klass, _status| error.is_a?(klass) }
        match ? match.last : 500
      end

      def log_unexpected(env, error)
        @logger.error({
                        request_id: env[::Middleware::RequestId::ENV_KEY],
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
