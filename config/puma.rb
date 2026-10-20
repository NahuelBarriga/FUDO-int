# frozen_string_literal: true

require_relative "env"
# default si falta la variable; Integer() falla si el valor no es numerics
max_threads = Integer(ENV.fetch("PUMA_MAX_THREADS", "3"))
threads max_threads, max_threads

workers Integer(ENV.fetch("WEB_CONCURRENCY", "0"))

port Integer(ENV.fetch("PORT", "9292"))

environment ENV.fetch("RACK_ENV", "development")
