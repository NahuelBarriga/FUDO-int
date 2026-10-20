# frozen_string_literal: true

require "jwt"

module AccessToken
  class Invalid < StandardError; end

  ALGORITHM = "HS256"
  SECRET = ENV.fetch("JWT_SECRET")
  raise ArgumentError, "JWT_SECRET must be at least 32 bytes" if SECRET.bytesize < 32

  TTL_SECONDS = Integer(ENV.fetch("JWT_TTL_SECONDS", "3600"))

  def self.issue(subject, now: Time.now)
    issued_at = now.to_i
    payload = { sub: subject, iat: issued_at, exp: issued_at + TTL_SECONDS }
    JWT.encode(payload, SECRET, ALGORITHM)
  end

  def self.verify(token)
    payload, _header = JWT.decode(token, SECRET, true, { algorithm: ALGORITHM, required_claims: %w[sub exp] })
    payload.fetch("sub")
  rescue JWT::DecodeError
    raise Invalid
  end
end
