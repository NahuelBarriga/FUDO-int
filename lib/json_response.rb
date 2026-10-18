# frozen_string_literal: true

require "json"

module JsonResponse
  CONTENT_TYPE = { "content-type" => "application/json" }.freeze

  def self.build(status, payload, headers = {})
    [status, CONTENT_TYPE.merge(headers), [JSON.generate(payload)]]
  end
end
