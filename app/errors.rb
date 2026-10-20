# frozen_string_literal: true

module Errors
  class AppError < StandardError
    def code
      "internal_error"
    end
  end

  class InvalidJson < AppError
    def initialize(message = "Request body is not valid JSON")
      super
    end

    def code
      "invalid_json"
    end
  end

  class InvalidBody < AppError
    def initialize(message = "Request body does not match the expected structure")
      super
    end

    def code
      "invalid_body"
    end
  end

  class NotFound < AppError
    def initialize(message = "Resource not found")
      super
    end

    def code
      "not_found"
    end
  end

  class ValidationFailed < AppError
    def initialize(message = "Validation failed for the provided data")
      super
    end

    def code
      "validation_failed"
    end
  end

  class UsernameTaken < AppError
    def initialize(message = "Username is already taken")
      super
    end

    def code
      "username_taken"
    end
  end

  class InvalidCredentials < AppError
    def initialize(message = "Invalid username or password")
      super
    end

    def code
      "invalid_credentials"
    end
  end

  class Unauthorized < AppError
    def initialize(message = "Unauthorized")
      super
    end

    def code
      "unauthorized"
    end
  end

  class NameTaken < AppError
    def initialize(message = "Name is already taken")
      super
    end

    def code
      "name_taken"
    end
  end

  class ServiceUnavailable < AppError
    def initialize(message = "Service unavailable")
      super
    end

    def code
      "service_unavailable"
    end
  end
end
