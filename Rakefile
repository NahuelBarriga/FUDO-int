# frozen_string_literal: true

MIGRATIONS_DIR = File.expand_path("db/migrations", __dir__)

namespace :db do
  task :environment do
    require_relative "config/boot"
    Sequel.extension :migration
  end

  desc "Aplica las migraciones pendientes"
  task migrate: :environment do
    Sequel::Migrator.run(DB, MIGRATIONS_DIR)
    puts "Esquema en la versiC3n #{current_version}"
  end

  desc "Revierte la C:ltima migraciC3n"
  task rollback: :environment do
    target = [current_version - 1, 0].max
    Sequel::Migrator.run(DB, MIGRATIONS_DIR, target: target)
    puts "Esquema en la versiC3n #{current_version}"
  end
end

def current_version
  DB.table_exists?(:schema_info) ? DB[:schema_info].get(:version) : 0
end
