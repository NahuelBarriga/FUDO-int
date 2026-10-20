# frozen_string_literal: true

require_relative "../../lib/password"

RSpec.describe Password do
  describe ".digest" do
    it "never contains the plain password" do
      expect(described_class.digest("secret-123")).not_to include("secret-123")
    end

    it "uses a different salt every time" do
      expect(described_class.digest("secret-123")).not_to eq(described_class.digest("secret-123"))
    end

    it "uses the cost from BCRYPT_COST" do
      expect(described_class.digest("secret-123")).to start_with("$2a$04$")
    end
  end

  describe ".matches?" do
    let(:digest) { described_class.digest("secret-123") }

    it "accepts the right password" do
      expect(described_class.matches?("secret-123", digest)).to be(true)
    end

    it "rejects a wrong password" do
      expect(described_class.matches?("wrong", digest)).to be(false)
    end
  end
end
