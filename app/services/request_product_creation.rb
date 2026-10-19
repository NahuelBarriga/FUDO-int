# frozen_string_literal: true

require_relative "../errors"
require_relative "../jobs/create_product"
require_relative "../models/product"
require_relative "../models/product_request"

module Services
  class RequestProductCreation
    NAME_LENGTH = (1..100)

    def call(user_id:, name:)
      name = name.strip
      validate!(name)
      ensure_name_available!(user_id, name)

      product_request = Models::ProductRequest.create(user_id: user_id, name: name)
      enqueue!(product_request)
      product_request
    end

    private

    def validate!(name)
      return if NAME_LENGTH.cover?(name.length)

      raise Errors::ValidationFailed, "name must be 1-100 characters (after trimming spaces)"
    end

    def ensure_name_available!(user_id, name)
      same_name = { Sequel.function(:lower, :name) => Sequel.function(:lower, name) }

      product_exists = !Models::Product.where(user_id: user_id).where(same_name).empty?
      pending_exists = !Models::ProductRequest.where(user_id: user_id, status: "pending").where(same_name).empty?

      raise Errors::NameTaken if product_exists || pending_exists
    end

    def enqueue!(product_request)
      Jobs::CreateProduct.perform_in(Jobs::CreateProduct::DELAY_SECONDS, product_request.id)
    rescue RedisClient::Error
      product_request.update(status: "failed", error: "enqueue_failed")
      raise Errors::ServiceUnavailable
    end
  end
end
