# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "bcrypt", "~> 3.1"
gem "jwt", "~> 3.3"
gem "logger", "~> 1.7"
gem "pg", "~> 1.7"
gem "puma", "~> 8.0"
gem "rack", "~> 3.2"
gem "rake", "~> 13.4"
gem "sequel", "~> 5.109"
gem "sidekiq", "~> 8.1"

group :development do
  gem "rerun", "~> 0.14.0"
  gem "rubocop", "~> 1.92"
  gem "rubocop-rspec", "~> 3.10"
  gem "rubocop-performance", "~> 1.27"
end

group :development, :test do
  gem "dotenv", "~> 3.2"
  gem "irb", "~> 1.18"
end

group :test do 
  gem "rspec", "~> 3.13"
  gem "rack-test", "~> 2.2"
  gem "simplecov", "~> 1.3"
end 


