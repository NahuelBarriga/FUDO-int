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

  class NotFound < AppError
    def initialize(message = "Resource not found")
      super
    end

    def code
      "not_found"
    end
  end
end
