# frozen_string_literal: true

require_relative "../../authenticated"
require_relative "../../serializers/user"
require_relative "../../../errors"
require_relative "../../../models/user"
require_relative "../../../../lib/json_response"

module Http
  module Endpoints
    module Auth
      class Me
        def call(env)
          user = Models::User[env[Authenticated::USER_ID_KEY]]
          raise Errors::Unauthorized, "Invalid or expired token" unless user

          JsonResponse.build(200, Serializers::User.call(user))
        end
      end
    end
  end
end
