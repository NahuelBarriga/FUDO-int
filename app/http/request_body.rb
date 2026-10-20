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
      unknown = body.keys - structure.keys #chequea si hay key no presentes en la estructura 
      missing = structure.keys - body.keys #chequea si faltan keys de la estructura en el body
      raise Errors::InvalidBody, "Request body contains unknown keys: #{unknown.join(", ")}" unless unknown.empty?
      raise Errors::InvalidBody, "Request body is missing required keys: #{missing.join(", ")}" unless missing.empty?
      structure.each do |key, type| #chequea los tipos 
        raise Errors::InvalidBody, "Key '#{key}' does not match the expected structure, must be '#{type.name.downcase} and is '#{body[key].class.name.downcase}'" unless body[key].is_a?(type)
      end
    end

    private_class_method :parse_json, :check_structure!
  end
end
