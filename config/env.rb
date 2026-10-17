# frozen_string_literal: true

require "bundler/setup"

if %w[development test].include?(ENV.fetch("RACK_ENV", "development"))
  require "dotenv"
  Dotenv.load
end
