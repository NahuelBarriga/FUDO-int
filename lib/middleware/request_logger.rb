# frozen_string_literal: true

require_relative "request_id"

module Middleware
  class RequestLogger
    def initialize(app, logger)
      @app = app
      @logger = logger
    end

    def call(env)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC) # uerza que la hora sea real
      status, headers, body = @app.call(env)

      entry = {
        request_id: env[RequestId::ENV_KEY],
        method: env["REQUEST_METHOD"],
        path: env["PATH_INFO"],
        status: status,
        duration_ms: elapsed_ms(started)
      }
      @logger.info(entry)

      [status, headers, body]
    end

    private

    def elapsed_ms(started)
      ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round(2)
    end
  end
end
