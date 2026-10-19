# frozen_string_literal: true

require "sidekiq"

redis_config = { url: ENV.fetch("REDIS_URL") }

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

Sidekiq.configure_server do |config|
  config.redis = redis_config
  config.concurrency = Integer(ENV.fetch("SIDEKIQ_CONCURRENCY", "5"))
  config.average_scheduled_poll_interval = Float(ENV.fetch("SIDEKIQ_POLL_INTERVAL", "1"))
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new
end
