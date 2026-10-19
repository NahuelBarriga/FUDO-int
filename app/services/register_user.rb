# frozen_string_literal: true

require_relative "../errors"
require_relative "../models/user"
require_relative "../../lib/password"

module Services
  class RegisterUser
    USERNAME_FORMAT = /\A[A-Za-z0-9_.-]{3,50}\z/
    PASSWORD_BYTES = (8..72)

    def call(username:, password:)
      validate!(username, password)
      Models::User.create(username: username, password_digest: Password.digest(password))
    rescue Sequel::UniqueConstraintViolation
      raise Errors::UsernameTaken
    end

    private

    def validate!(username, password)
      unless USERNAME_FORMAT.match?(username)
        raise Errors::ValidationFailed,
              "username must be 3-50 characters: letters, numbers, '_', '.' or '-'"
      end
      return if PASSWORD_BYTES.cover?(password.bytesize)

      raise Errors::ValidationFailed, "password must be 8-72 bytes long"
    end
  end
end
