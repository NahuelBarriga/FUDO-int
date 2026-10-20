# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["LOG_LEVEL"] = "warn"

require "simplecov"
SimpleCov.start do
  skip "/spec/"
  cover "{app,lib}/**/*.rb"
end

require_relative "../config/boot"
require "rack/test"

Sidekiq.testing!(:fake)

Dir[File.join(__dir__, "support", "**", "*.rb")].sort.each { |file| require file }

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
  end
end
