# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["LOG_LEVEL"] = "warn"
ENV["RATE_LIMIT_STORE"] = "memory"

require "simplecov"
SimpleCov.start do
  skip "/spec/"
  cover "{app,lib}/**/*.rb"
end

require_relative "../config/boot"
require "rack/test"

# Falla con un mensaje claro si la base de test no está migrada
# (los modelos leen el esquema al cargarse, D34).
Sequel.extension :migration
begin
  Sequel::Migrator.check_current(DB, File.expand_path("../db/migrations", __dir__))
rescue Sequel::Migrator::NotCurrentError
  abort "La base de test no está migrada. Corré: RACK_ENV=test bundle exec rake db:migrate"
end

Sidekiq.testing!(:fake)

Dir[File.join(__dir__, "support", "**", "*.rb")].each { |file| require file }

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
  config.example_status_persistence_file_path = ".rspec_status"

  config.include Factories
  config.include RequestHelpers, type: :request

  config.around do |example|
    DB.transaction(rollback: :always, auto_savepoint: true) { example.run }
  end

  config.before do
    Sidekiq::Job.clear_all
    RateLimits.store.clear
  end
end
