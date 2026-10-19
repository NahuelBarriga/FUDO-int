# frozen_string_literal: true

require "time"

module Http
  module Serializers
    module ProductRequest
      def self.call(product_request)
        {
          id: product_request.id,
          name: product_request.name,
          status: product_request.status,
          product_id: product_request.product_id,
          error: product_request.error,
          created_at: product_request.created_at.iso8601
        }
      end
    end
  end
end
