# frozen_string_literal: true

require_relative "../../../app/services/register_user"

RSpec.describe Services::RegisterUser do
  subject(:service) { described_class.new }

  it "creates a user with a hashed password" do
    user = service.call(username: "nahuel", password: "supersecreta")

    expect(user.password_digest).not_to eq("supersecreta")
    expect(Password.matches?("supersecreta", user.password_digest)).to be(true)
  end

  it "keeps the username as written" do
    expect(service.call(username: "Nahuel", password: "supersecreta").username).to eq("Nahuel")
  end

  it "rejects a username already taken, ignoring case (RN-07)" do
    service.call(username: "nahuel", password: "supersecreta")

    expect { service.call(username: "NAHUEL", password: "supersecreta") }
      .to raise_error(Errors::UsernameTaken)
  end

  ["ab", "a" * 51, "with space", "ñandu", "semi;colon"].each do |username|
    it "rejects the username #{username[0, 20].inspect}" do
      expect { service.call(username: username, password: "supersecreta") }
        .to raise_error(Errors::ValidationFailed)
    end
  end

  ["abc", "a" * 50, "nahuel.barriga", "nahuel_b-1"].each do |username|
    it "accepts the username #{username[0, 20].inspect}" do
      expect(service.call(username: username, password: "supersecreta").username).to eq(username)
    end
  end

  it "rejects a password shorter than 8 bytes" do
    expect { service.call(username: "nahuel", password: "short") }
      .to raise_error(Errors::ValidationFailed)
  end

  it "rejects a password longer than 72 bytes, counting bytes and not characters" do
    expect { service.call(username: "nahuel", password: "ñ" * 37) }
      .to raise_error(Errors::ValidationFailed)
  end

  it "accepts a password of exactly 72 bytes" do
    expect(service.call(username: "nahuel", password: "a" * 72).username).to eq("nahuel")
  end
end
