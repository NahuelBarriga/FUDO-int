# frozen_string_literal: true

require_relative "../lib/router"
require_relative "../app/http/endpoints/health"

module Routes
  def self.build
    router = Router.new
    router.get "/health", Http::Endpoints::Health.new
    router
  end
end
