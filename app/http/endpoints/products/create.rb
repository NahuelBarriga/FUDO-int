# frozen_string_literal: true

require_relative "../../authenticated"
require_relative "../../request_body"
require_relative "../../serializers/product_request"
require_relative "../../../jobs/create_product"
require_relative "../../../services/request_product_creation"
require_relative "../../../../lib/json_response"

module Http
  module Endpoints
    module Products
      class Create
        STRUCTURE = { "name" => String }.freeze

        def initialize
          @request_product_creation = Services::RequestProductCreation.new
        end

        def call(env)
          body = RequestBody.parse(env, STRUCTURE)
          product_request = @request_product_creation.call(
            user_id: env[Authenticated::USER_ID_KEY],
            name: body["name"]
          )

          JsonResponse.build(202, Serializers::ProductRequest.call(product_request), {
                               "location" => "/product_requests/#{product_request.id}",
                               "retry-after" => Jobs::CreateProduct::DELAY_SECONDS.to_s
                             })
        end
      end
    end
  end
end
