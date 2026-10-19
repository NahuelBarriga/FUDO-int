# frozen_string_literal: true

source "https://rubygems.org"

ruby file: ".ruby-version"

gem "logger", "~> 1.7"
gem "pg", "~> 1.7"
gem "puma", "~> 8.0"
gem "rack", "~> 3.2"
gem "sequel", "~> 5.109"

group :development do
  gem "rerun", "~> 0.14.0"
end

group :development, :test do
  gem "dotenv", "~> 3.2"
  gem "irb", "~> 1.18"
end
