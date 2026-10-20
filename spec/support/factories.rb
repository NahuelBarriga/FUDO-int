# frozen_string_literal: true

require "securerandom"
require_relative "../../app/models/product"
require_relative "../../app/models/product_request"
require_relative "../../app/models/user"
require_relative "../../lib/password"

# Métodos cortos para crear datos de prueba con valores únicos por defecto.
# Todo lo que crean se deshace al final de cada test (transacción con rollback).
module Factories
  def create_user(username: "user_#{SecureRandom.hex(4)}", password: "supersecreta")
    Models::User.create(username: username, password_digest: Password.digest(password))
  end

  def create_product(user:, name: "Product #{SecureRandom.hex(4)}")
    Models::Product.create(user_id: user.id, name: name)
  end

  def create_product_request(user:, name: "Request #{SecureRandom.hex(4)}")
    Models::ProductRequest.create(user_id: user.id, name: name)
  end
end
