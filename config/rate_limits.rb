# frozen_string_literal: true

require "json"
require "rack/request"
require "stringio"
require_relative "../lib/middleware/rate_limiter"

module RateLimits
  MINUTE = 60
  HOUR = 3600

  def self.rules
    [
      rule(:general, "RATE_LIMIT_GENERAL", 300, MINUTE) { |env| client_ip(env) },
      rule(:login_ip, "RATE_LIMIT_LOGIN_IP", 10, MINUTE) { |env| client_ip(env) if login?(env) },
      rule(:login_username, "RATE_LIMIT_LOGIN_USERNAME", 5, MINUTE) { |env| login_username(env) if login?(env) },
      rule(:register_ip, "RATE_LIMIT_REGISTER_IP", 10, HOUR) { |env| client_ip(env) if register?(env) }
    ]
  end

  def self.store
    @store ||= if ENV.fetch("RATE_LIMIT_STORE", "redis") == "memory"
                 Middleware::RateLimiter::MemoryStore.new
               else
                 Middleware::RateLimiter::RedisStore.new(Sidekiq.redis_pool)
               end
  end

  def self.rule(name, env_var, default_limit, period, &discriminator)
    Middleware::RateLimiter::Rule.new(
      name: name,
      limit: Integer(ENV.fetch(env_var, default_limit.to_s)),
      period: period,
      discriminator: discriminator
    )
  end

  def self.client_ip(env) = Rack::Request.new(env).ip

  def self.login?(env) = env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"] == "/auth/login"

  def self.register?(env) = env["REQUEST_METHOD"] == "POST" && env["PATH_INFO"] == "/auth/register"

  # Lee el username del body y lo vuelve a dejar disponible para el endpoint.
  def self.login_username(env)
    raw = env["rack.input"]&.read.to_s
    env["rack.input"] = StringIO.new(raw)

    body = JSON.parse(raw)
    username = body["username"] if body.is_a?(Hash)
    username.downcase if username.is_a?(String)
  rescue JSON::ParserError
    nil
  end

  private_class_method :rule, :client_ip, :login?, :register?, :login_username
end
