# frozen_string_literal: true

module Middleware
  class RateLimiter
    class Exceeded < StandardError
      attr_reader :retry_after

      def initialize(retry_after)
        @retry_after = retry_after
        super("Rate limit exceeded")
      end
    end

    class StoreUnavailable < StandardError; end

    Rule = Data.define(:name, :limit, :period, :discriminator)

    # Contadores en Redis, compraten por todos los procesos.
    class RedisStore
      def initialize(pool)
        @pool = pool
      end

      def increment(key, ttl)
        @pool.with do |conn|
          count = conn.call("INCR", key)
          conn.call("EXPIRE", key, ttl, "NX")
          count
        end
      rescue RedisClient::Error => e
        raise StoreUnavailable, e.message
      end
    end

    # Contadores en memoria: para tests (un solo proceso, sin vencimiento).
    class MemoryStore
      def initialize
        @counts = Hash.new(0)
        @mutex = Mutex.new
      end

      def increment(key, _ttl)
        @mutex.synchronize { @counts[key] += 1 }
      end

      def clear
        @mutex.synchronize { @counts.clear }
      end
    end

    def initialize(app, rules, store, logger)
      @app = app
      @rules = rules
      @store = store
      @logger = logger
    end

    def call(env)
      @rules.each { |rule| enforce!(rule, env) }
      @app.call(env)
    end

    private

    def enforce!(rule, env)
      key = rule.discriminator.call(env)
      return unless key

      now = Time.now.to_i
      count = @store.increment(window_key(rule, key, now), rule.period)
      raise Exceeded, seconds_left(rule, now) if count > rule.limit
    rescue StoreUnavailable => e
      @logger.warn({ event: "rate_limit_store_unavailable", rule: rule.name, error: e.message })
    end

    def window_key(rule, key, now) = "rate_limit:#{rule.name}:#{key}:#{now / rule.period}"

    def seconds_left(rule, now) = rule.period - (now % rule.period)
  end
end
