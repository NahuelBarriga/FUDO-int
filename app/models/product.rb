# frozen_string_literal: true

module Models
  class Product < Sequel::Model(:products)
    plugin :timestamps, update_on_create: true
  end
end
