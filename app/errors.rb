# frozen_string_literal: true

module Errors
  class AppError < StandardError
    def self.code = self::CODE

    def initialize(message = self.class::DEFAULT_MESSAGE)
      super
    end

    def code = self.class.code
  end

  class InvalidJson < AppError
    CODE = "invalid_json"
    DEFAULT_MESSAGE = "Request body is not valid JSON"
  end

  class InvalidBody < AppError
    CODE = "invalid_body"
    DEFAULT_MESSAGE = "Request body does not match the expected structure"
  end

  class NotFound < AppError
    CODE = "not_found"
    DEFAULT_MESSAGE = "Resource not found"
  end

  class ValidationFailed < AppError
    CODE = "validation_failed"
    DEFAULT_MESSAGE = "Validation failed for the provided data"
  end

  class UsernameTaken < AppError
    CODE = "username_taken"
    DEFAULT_MESSAGE = "Username is already taken"
  end

  class InvalidCredentials < AppError
    CODE = "invalid_credentials"
    DEFAULT_MESSAGE = "Invalid username or password"
  end

  class Unauthorized < AppError
    CODE = "unauthorized"
    DEFAULT_MESSAGE = "Unauthorized"
  end

  class NameTaken < AppError
    CODE = "name_taken"
    DEFAULT_MESSAGE = "Name is already taken"
  end

  class ServiceUnavailable < AppError
    CODE = "service_unavailable"
    DEFAULT_MESSAGE = "Service unavailable"
  end
end
