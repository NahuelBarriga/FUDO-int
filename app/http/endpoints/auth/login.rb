# frozen_string_literal: true

require_relative "../../request_body"
require_relative "../../../services/authenticate_user"
require_relative "../../../../lib/access_token"
require_relative "../../../../lib/json_response"

module Http
  module Endpoints
    module Auth
      class Login
        STRUCTURE = { "username" => String, "password" => String }.freeze

        def initialize
          @authenticate_user = Services::AuthenticateUser.new
        end

        def call(env)
          body = RequestBody.parse(env, STRUCTURE)
          user = @authenticate_user.call(username: body["username"], password: body["password"])

          JsonResponse.build(200, {
                               access_token: AccessToken.issue(user.id),
                               token_type: "Bearer",
                               expires_in: AccessToken::TTL_SECONDS
                             })
        end
      end
    end
  end
end
