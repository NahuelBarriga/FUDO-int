# frozen_string_literal: true

module Uuid
  FORMAT = /\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/i

  def self.valid?(value)
    FORMAT.match?(value.to_s)
  end
end
