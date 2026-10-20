# frozen_string_literal: true

require_relative "../../authenticated"
require_relative "../../serializers/product"
require_relative "../../../errors"
require_relative "../../../models/product"
require_relative "../../../../lib/json_response"
require_relative "../../../../lib/router"
require_relative "../../../../lib/uuid"

module Http
  module Endpoints
    module Products
      class Show
        def call(env)
          id = env[Router::PARAMS_KEY]["id"]
          raise Errors::NotFound, "Product not found" unless Uuid.valid?(id)

          product = Models::Product.where(id: id, user_id: env[Authenticated::USER_ID_KEY]).first
          raise Errors::NotFound, "Product not found" unless product

          JsonResponse.build(200, Serializers::Product.call(product))
        end
      end
    end
  end
end
