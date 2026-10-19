# frozen_string_literal: true

require "time"

module Http
  module Serializers
    module User
      def self.call(user)
        { id: user.id, username: user.username, created_at: user.created_at.iso8601 }
      end
    end
  end
end
