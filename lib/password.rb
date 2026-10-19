# frozen_string_literal: true

require "bcrypt"

module Password
  def self.digest(plain)
    BCrypt::Password.create(plain, cost: cost).to_s
  end

  def self.matches?(plain, digest)
    BCrypt::Password.new(digest) == plain
  end

  def self.cost
    Integer(ENV.fetch("BCRYPT_COST", BCrypt::Engine::DEFAULT_COST.to_s))
  end

  private_class_method :cost
end
