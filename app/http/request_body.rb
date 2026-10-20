# frozen_string_literal: true

require "json"
require_relative "../errors"

module Http
  module RequestBody
    def self.parse(env, structure)
      input = env["rack.input"]
      raw = input ? input.read : ""
      raise Errors::InvalidJson, "Request body is required" if raw.strip.empty?

      body = parse_json(raw)
      raise Errors::InvalidBody, "Request body must be a JSON object" unless body.is_a?(Hash)

      check_structure!(body, structure)
      body
    end

    def self.parse_json(raw)
      JSON.parse(raw)
    rescue JSON::ParserError
      raise Errors::InvalidJson
    end

    def self.check_structure!(body, structure)
      reject_keys!(body.keys - structure.keys, "contains unknown keys")
      reject_keys!(structure.keys - body.keys, "is missing required keys")
      structure.each { |key, type| check_type!(key, body[key], type) }
    end

    def self.reject_keys!(keys, problem)
      return if keys.empty?

      raise Errors::InvalidBody, "Request body #{problem}: #{keys.join(", ")}"
    end

    def self.check_type!(key, value, type)
      return if value.is_a?(type)

      raise Errors::InvalidBody, "Field '#{key}' must be a #{type.name.downcase}, got #{value.class.name.downcase}"
    end

    private_class_method :parse_json, :check_structure!, :reject_keys!, :check_type!

    private_class_method :parse_json, :check_structure!
  end
end
