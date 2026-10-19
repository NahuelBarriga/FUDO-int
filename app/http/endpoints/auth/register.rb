# frozen_string_literal: true

require_relative "../../request_body"
require_relative "../../../services/register_user"
require_relative "../../../../lib/json_response"
require_relative "../../serializers/user"

module Http
  module Endpoints
    module Auth
      class Register
        STRUCTURE = { "username" => String, "password" => String }.freeze

        def initialize
          @register_user = Services::RegisterUser.new
        end

        def call(env)
          body = RequestBody.parse(env, STRUCTURE)
          user = @register_user.call(username: body["username"], password: body["password"])

          JsonResponse.build(201, Serializers::User.call(user))
        end
      end
    end
  end
end
