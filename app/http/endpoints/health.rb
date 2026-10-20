# frozen_string_literal: true

require "sidekiq/api"
require_relative "../../../lib/json_response"

module Http
  module Endpoints
    class Health
      CRITICAL = %i[postgres redis].freeze

      def call(_env)
        checks = { postgres: check_postgres, redis: check_redis, worker: check_worker }
        status = overall_status(checks)

        JsonResponse.build(status == "down" ? 503 : 200,
                           { status: status, checks: checks },
                           { "cache-control" => "no-store" })
      end

      private

      def overall_status(checks)
        return "down" if CRITICAL.any? { |name| checks[name] == "down" }

        checks.value?("down") ? "degraded" : "ok"
      end

      def check_postgres
        DB.test_connection
        "up"
      rescue Sequel::Error
        "down"
      end

      def check_redis
        Sidekiq.redis { |conn| conn.call("PING") }
        "up"
      rescue RedisClient::Error
        "down"
      end

      def check_worker
        Sidekiq::ProcessSet.new.size.positive? ? "up" : "down"
      rescue RedisClient::Error
        "down"
      end
    end
  end
end
