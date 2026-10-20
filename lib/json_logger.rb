# frozen_string_literal: true

require "json"
require "logger"
require "time"

module JsonLogger
  FORMATTER = lambda do |severity, time, _progname, message|
    fields = message.is_a?(Hash) ? message : { message: message.to_s }
    entry = { time: time.getutc.iso8601(3), level: severity }.merge(fields)
    "#{JSON.generate(entry)}\n" # salto de linea al final
  end

  def self.build(output = $stdout, level: "info")
    output.sync = true if output.respond_to?(:sync=) # el sync es para que salga al instante

    logger = Logger.new(output)
    logger.level = level
    logger.formatter = FORMATTER
    logger
  end
end
