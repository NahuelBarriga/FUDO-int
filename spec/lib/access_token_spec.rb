# frozen_string_literal: true

require "jwt"
require_relative "../../lib/access_token"

RSpec.describe AccessToken do
  let(:future) { Time.now.to_i + 60 }

  it "returns the subject of a token it issued" do
    token = described_class.issue("user-1")
    expect(described_class.verify(token)).to eq("user-1")
  end

  it "rejects a tampered token" do
    header, payload, signature = described_class.issue("user-1").split(".")
    tampered_payload = payload.end_with?("A") ? "#{payload[0..-2]}B" : "#{payload[0..-2]}A"

    expect { described_class.verify([header, tampered_payload, signature].join(".")) }
      .to raise_error(AccessToken::Invalid)
  end

  it "rejects an expired token" do
    token = described_class.issue("user-1", now: Time.now - AccessToken::TTL_SECONDS - 1)
    expect { described_class.verify(token) }.to raise_error(AccessToken::Invalid)
  end

  it "rejects a token signed with another secret" do
    token = JWT.encode({ sub: "user-1", exp: future }, "another-secret", "HS256")
    expect { described_class.verify(token) }.to raise_error(AccessToken::Invalid)
  end

  it "rejects an unsigned token (alg: none)" do
    token = JWT.encode({ sub: "user-1", exp: future }, nil, "none")
    expect { described_class.verify(token) }.to raise_error(AccessToken::Invalid)
  end

  it "rejects a token without exp" do
    token = JWT.encode({ sub: "user-1" }, AccessToken::SECRET, "HS256")
    expect { described_class.verify(token) }.to raise_error(AccessToken::Invalid)
  end

  it "rejects garbage" do
    expect { described_class.verify("garbage") }.to raise_error(AccessToken::Invalid)
  end
end
