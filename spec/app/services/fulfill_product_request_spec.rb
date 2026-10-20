# frozen_string_literal: true

require "securerandom"
require_relative "../../../app/services/fulfill_product_request"

RSpec.describe Services::FulfillProductRequest do
  subject(:service) { described_class.new }

  let(:user) { create_user }
  let(:product_request) { create_product_request(user: user, name: "Coca") }

  it "creates the product and completes the request in one step" do
    service.call(product_request_id: product_request.id)
    product_request.refresh

    expect(product_request.status).to eq("completed")
    expect(Models::Product[product_request.product_id].name).to eq("Coca")
  end

  it "fails the request with name_taken when the product already exists (RN-05)" do
    create_product(user: user, name: "COCA")

    service.call(product_request_id: product_request.id)
    product_request.refresh

    expect(product_request.status).to eq("failed")
    expect(product_request.error).to eq("name_taken")
    expect(Models::Product.where(user_id: user.id).count).to eq(1)
  end

  it "does nothing when the request is no longer pending (idempotency)" do
    service.call(product_request_id: product_request.id)

    expect { service.call(product_request_id: product_request.id) }
      .not_to change(Models::Product, :count)
  end

  it "does nothing when the request does not exist" do
    expect { service.call(product_request_id: SecureRandom.uuid) }
      .not_to change(Models::Product, :count)
  end
end
