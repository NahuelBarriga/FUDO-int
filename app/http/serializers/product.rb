# frozen_string_literal: true

require "time"

module Http
  module Serializers
    module Product
      def self.call(product)
        { id: product.id, name: product.name, created_at: product.created_at.iso8601 }
      end
    end
  end
end
