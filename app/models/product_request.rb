# frozen_string_literal: true

module Models
  class ProductRequest < Sequel::Model(:product_requests)
    plugin :timestamps, update_on_create: true
  end
end
