# frozen_string_literal: true

require_relative "../models/product_request"

module Services
  class FailProductRequest
    def call(product_request_id:, error:)
      Models::ProductRequest
        .where(id: product_request_id, status: "pending")
        .update(status: "failed", error: error, updated_at: Sequel::CURRENT_TIMESTAMP)
    end
  end
end
