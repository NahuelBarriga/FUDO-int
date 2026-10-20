# frozen_string_literal: true

require "rack/request"
require_relative "../../authenticated"
require_relative "../../serializers/product"
require_relative "../../../errors"
require_relative "../../../models/product"
require_relative "../../../../lib/json_response"

module Http
  module Endpoints
    module Products
      class Index
        DEFAULT_LIMIT = 20
        MAX_LIMIT = 100
        DIGITS = /\A\d+\z/

        def call(env)
          params = Rack::Request.new(env).GET
          limit = integer_param(params, "limit", DEFAULT_LIMIT, 1..MAX_LIMIT)
          offset = integer_param(params, "offset", 0, 0..)

          user_products = Models::Product.where(user_id: env[Authenticated::USER_ID_KEY])
          page = user_products.order(:id).limit(limit).offset(offset).all

          JsonResponse.build(200, {
            data: page.map { |product| Serializers::Product.call(product) },
            meta: { limit: limit, offset: offset, total: user_products.count }
          })
        end

        private

        def integer_param(params, name, default, range)
          value = params.fetch(name, default.to_s)
          valid = value.is_a?(String) && DIGITS.match?(value) && range.cover?(Integer(value, 10))
          raise Errors::ValidationFailed, "#{name} must be an integer in #{range}" unless valid

          Integer(value, 10)
        end
      end
    end
  end
end
