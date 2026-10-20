# frozen_string_literal: true

require_relative "../../../app/services/request_product_creation"

RSpec.describe Services::RequestProductCreation do
  subject(:service) { described_class.new }

  let(:user) { create_user }

  it "creates a pending request with the trimmed name (RN-02)" do
    product_request = service.call(user_id: user.id, name: "  Coca  ")

    expect(product_request.status).to eq("pending")
    expect(product_request.name).to eq("Coca")
  end

  it "enqueues the job with the request id and a 5 second delay" do
    product_request = service.call(user_id: user.id, name: "Coca")
    job = Jobs::CreateProduct.jobs.first

    expect(Jobs::CreateProduct.jobs.size).to eq(1)
    expect(job["args"]).to eq([product_request.id])
    expect(job["at"]).to be_within(1).of(Time.now.to_f + Jobs::CreateProduct::DELAY_SECONDS)
  end

  ["   ", "a" * 101].each do |name|
    it "rejects the name #{name[0, 20].inspect}" do
      expect { service.call(user_id: user.id, name: name) }.to raise_error(Errors::ValidationFailed)
    end
  end

  it "accepts a name of 100 characters, any character" do
    expect(service.call(user_id: user.id, name: "ñ" * 100).status).to eq("pending")
  end

  it "rejects a name already used by a product of the user, ignoring case (RN-04)" do
    create_product(user: user, name: "Coca")

    expect { service.call(user_id: user.id, name: "COCA") }.to raise_error(Errors::NameTaken)
  end

  it "rejects a name with a pending request of the user (RN-04)" do
    create_product_request(user: user, name: "Coca")

    expect { service.call(user_id: user.id, name: "coca") }.to raise_error(Errors::NameTaken)
  end

  it "allows a name whose previous request failed" do
    create_product_request(user: user, name: "Coca").update(status: "failed", error: "name_taken")

    expect(service.call(user_id: user.id, name: "Coca").status).to eq("pending")
  end

  it "allows a name used by another user" do
    create_product(user: create_user, name: "Coca")

    expect(service.call(user_id: user.id, name: "Coca").status).to eq("pending")
  end

  context "when Redis is down (dual write)" do
    before do
      allow(Jobs::CreateProduct).to receive(:perform_in).and_raise(RedisClient::CannotConnectError)
    end

    it "marks the request as failed and raises ServiceUnavailable" do
      expect { service.call(user_id: user.id, name: "Coca") }.to raise_error(Errors::ServiceUnavailable)

      product_request = Models::ProductRequest.first(user_id: user.id)
      expect(product_request.status).to eq("failed")
      expect(product_request.error).to eq("enqueue_failed")
    end
  end
end
