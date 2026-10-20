# frozen_string_literal: true

require_relative "../../../app/services/authenticate_user"

RSpec.describe Services::AuthenticateUser do
  subject(:service) { described_class.new }

  let!(:user) { create_user(username: "nahuel", password: "supersecreta") }

  it "returns the user for valid credentials, ignoring the username case" do
    expect(service.call(username: "NAHUEL", password: "supersecreta")).to eq(user)
  end

  it "rejects a wrong password" do
    expect { service.call(username: "nahuel", password: "incorrecta") }
      .to raise_error(Errors::InvalidCredentials)
  end

  it "rejects an unknown username with the same error (RN-08)" do
    expect { service.call(username: "noexiste", password: "incorrecta") }
      .to raise_error(Errors::InvalidCredentials)
  end

  it "still checks a password when the user does not exist (timing attack)" do
    expect(Password).to receive(:matches?).once.and_call_original

    expect { service.call(username: "noexiste", password: "incorrecta") }
      .to raise_error(Errors::InvalidCredentials)
  end
end
