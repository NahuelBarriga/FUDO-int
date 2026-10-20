# frozen_string_literal: true

require "json"
require "stringio"
require_relative "../../lib/json_logger"

RSpec.describe JsonLogger, :aggregate_failures do
  let(:output) { StringIO.new }
  let(:logger) { described_class.build(output, level: "info") }

  it "writes one JSON line with time (UTC) and level" do
    logger.info({ event: "test" })
    entry = JSON.parse(output.string)

    expect(entry).to include("level" => "INFO", "event" => "test")
    expect(entry["time"]).to end_with("Z")
    expect(output.string).to end_with("\n")
  end

  it "wraps plain strings in a message field" do
    logger.warn("plain text")

    expect(JSON.parse(output.string)).to include("level" => "WARN", "message" => "plain text")
  end

  it "ignores entries below the configured level" do
    logger.debug("hidden")

    expect(output.string).to be_empty
  end
end
