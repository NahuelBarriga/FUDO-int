# frozen_string_literal: true

require_relative "../../../lib/json_response"

module Http
  module Endpoints
    class Health
      def call(_env)
        JsonResponse.build(200, { status: "ok" })
      end
    end
  end
end
