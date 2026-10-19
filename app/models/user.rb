# frozen_string_literal: true

module Models
  class User < Sequel::Model(:users)
    plugin :timestamps, update_on_create: true
  end
end
