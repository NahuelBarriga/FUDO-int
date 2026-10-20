# frozen_string_literal: true

require "stringio"
require_relative "../../../app/http/request_body"

RSpec.describe Http::RequestBody do
  let(:structure) { { "name" => String } }

  def parse(raw)
    described_class.parse({ "rack.input" => StringIO.new(raw) }, structure)
  end

  it "returns the parsed body when it matches the structure" do
    expect(parse('{"name":"Coca"}')).to eq("name" => "Coca")
  end

  it "treats a missing rack.input as an empty body" do
    expect { described_class.parse({}, structure) }.to raise_error(Errors::InvalidJson)
  end

  {
    "an empty body" => ["", Errors::InvalidJson],
    "a blank body" => ["   ", Errors::InvalidJson],
    "invalid JSON" => ["{nope", Errors::InvalidJson],
    "a JSON array" => ["[1,2]", Errors::InvalidBody],
    "a JSON string" => ['"Coca"', Errors::InvalidBody],
    "an unknown field" => ['{"name":"Coca","color":"red"}', Errors::InvalidBody],
    "a missing field" => ["{}", Errors::InvalidBody],
    "a field with the wrong type" => ['{"name":123}', Errors::InvalidBody]
  }.each do |description, (raw, error)|
    it "rejects #{description}" do
      expect { parse(raw) }.to raise_error(error)
    end
  end
end
