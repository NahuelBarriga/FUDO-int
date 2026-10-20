# frozen_string_literal: true

require_relative "../lib/router"
require_relative "../app/http/endpoints/health"
require_relative "../app/http/endpoints/auth/register"
require_relative "../app/http/endpoints/auth/login"
require_relative "../app/http/authenticated"
require_relative "../app/http/endpoints/auth/me"
require_relative "../app/http/endpoints/products/create"
require_relative "../app/http/endpoints/products/show"
require_relative "../app/http/endpoints/products/index"
require_relative "../app/http/endpoints/authors"
require_relative "../app/http/endpoints/product_requests/show"

module Routes
  def self.build
    router = Router.new

    #-- public --
    router.get "/health", Http::Endpoints::Health.new
    router.post "/auth/register", Http::Endpoints::Auth::Register.new
    router.post "/auth/login", Http::Endpoints::Auth::Login.new
    router.get "/AUTHORS", Http::Endpoints::Authors.new

    #-- protected --
    router.get "/auth/me", Http::Authenticated.new(Http::Endpoints::Auth::Me.new)
    router.post "/products", Http::Authenticated.new(Http::Endpoints::Products::Create.new)
    router.get "/products", Http::Authenticated.new(Http::Endpoints::Products::Index.new)
    router.get "/products/:id", Http::Authenticated.new(Http::Endpoints::Products::Show.new)
    router.get "/product_requests/:id", Http::Authenticated.new(Http::Endpoints::ProductRequests::Show.new)

    router
  end
end
