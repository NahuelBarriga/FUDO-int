# frozen_string_literal: true

require "bundler/setup"

env = ENV.fetch("RACK_ENV", "development")

if %w[development test].include?(env)
  require "dotenv"

  root = File.expand_path("..", __dir__)
  Dotenv.load(File.join(root, ".env.#{env}"), File.join(root, ".env"))
end
