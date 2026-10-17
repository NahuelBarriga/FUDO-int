# frozen_string_literal: true

require_relative "config/boot"

map "/health" do
  run Http::Endpoints::Health.new
end