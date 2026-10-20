# frozen_string_literal: true

require_relative "../../authenticated"
require_relative "../../serializers/product_request"
require_relative "../../../errors"
require_relative "../../../models/product_request"
require_relative "../../../../lib/json_response"
require_relative "../../../../lib/router"
require_relative "../../../../lib/uuid"

module Http
  module Endpoints
    module ProductRequests
      class Show
        def call(env)
          id = env[Router::PARAMS_KEY]["id"]
          raise Errors::NotFound, "Product request not found" unless Uuid.valid?(id)

          product_request = Models::ProductRequest
            .where(id: id, user_id: env[Authenticated::USER_ID_KEY])
            .first
          raise Errors::NotFound, "Product request not found" unless product_request

          JsonResponse.build(200, Serializers::ProductRequest.call(product_request), headers_for(product_request))
        end

        private

        def headers_for(product_request)
          product_request.status == "pending" ? { "retry-after" => "1" } : {}
        end
      end
    end
  end
end
