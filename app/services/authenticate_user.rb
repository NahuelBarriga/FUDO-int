# frozen_string_literal: true

require_relative "../errors"
require_relative "../models/user"
require_relative "../../lib/password"

module Services
  class AuthenticateUser
    # hace esto para igualar los tiempos de respuesta de usuario no existente y contraseña incorrecta
    # para no dar pistas a un atacante
    DUMMY_DIGEST = Password.digest("dummy-password-to-equalize-timing")

    def call(username:, password:)
      user = Models::User.where(
        Sequel.function(:lower, :username) => Sequel.function(:lower, username)
      ).first

      digest = user ? user.password_digest : DUMMY_DIGEST
      password_ok = Password.matches?(password, digest)
      raise Errors::InvalidCredentials unless user && password_ok

      user
    end
  end
end
