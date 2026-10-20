# frozen_string_literal: true

require_relative "fail_product_request"
require_relative "../models/product"
require_relative "../models/product_request"

module Services
  class FulfillProductRequest
    def initialize
      @fail_product_request = FailProductRequest.new
    end

    def call(product_request_id:)
      DB.transaction do
        product_request = Models::ProductRequest.where(id: product_request_id).for_update.first # bloquea el registro
        fulfill(product_request) if product_request&.status == "pending"
      end
    rescue Sequel::UniqueConstraintViolation
      @fail_product_request.call(product_request_id: product_request_id, error: "name_taken")
    end

    private

    def fulfill(product_request)
      product = Models::Product.create(user_id: product_request.user_id, name: product_request.name)
      product_request.update(status: "completed", product_id: product.id)
    end
  end
end
