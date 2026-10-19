# frozen_string_literal: true

require "sequel"

Sequel.default_timezone = :utc #para evitar problemas con los timezone

DB = Sequel.connect(
  ENV.fetch("DATABASE_URL"),
  max_connections: Integer(ENV.fetch("DB_POOL", "5"))
)
