# frozen_string_literal: true

require_relative "../../lib/uuid"

RSpec.describe Uuid do
  describe ".valid?" do
    it "accepts a UUID" do
      expect(described_class.valid?("0192f3b4-1c2d-7e8f-9a0b-1c2d3e4f5a6b")).to be(true)
    end

    it "accepts uppercase letters" do
      expect(described_class.valid?("0192F3B4-1C2D-7E8F-9A0B-1C2D3E4F5A6B")).to be(true)
    end

    it "rejects a string that is not a UUID" do
      expect(described_class.valid?("abc")).to be(false)
    end

    it "rejects nil" do
      expect(described_class.valid?(nil)).to be(false)
    end
  end
end
