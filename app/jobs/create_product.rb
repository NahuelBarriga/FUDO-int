# frozen_string_literal: true

require "sidekiq"
require_relative "../services/fail_product_request"
require_relative "../services/fulfill_product_request"

module Jobs
  class CreateProduct
    include Sidekiq::Job

    DELAY_SECONDS = 5

    sidekiq_options retry: 5

    sidekiq_retries_exhausted do |job, _exception|
      Services::FailProductRequest.new.call(product_request_id: job["args"].first, error: "creation_failed")
    end

    def perform(product_request_id)
      Services::FulfillProductRequest.new.call(product_request_id: product_request_id)
    end
  end
end
