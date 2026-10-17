# frozen_string_literal: true

require "json"

module Http
  module Endpoints
    class Health
      def call(_env)
        [200, { "content-type" => "application/json" }, [JSON.generate({ status: "ok" })]]
      end
    end
  end
end