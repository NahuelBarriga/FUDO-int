# frozen_string_literal: true

require_relative "../../../app/services/fail_product_request"

RSpec.describe Services::FailProductRequest do
  subject(:service) { described_class.new }

  let(:product_request) { create_product_request(user: create_user) }

  it "fails a pending request with the given error" do
    service.call(product_request_id: product_request.id, error: "creation_failed")
    product_request.refresh

    expect(product_request.status).to eq("failed")
    expect(product_request.error).to eq("creation_failed")
  end

  it "does not touch a request in a final state (SRS 4.3)" do
    service.call(product_request_id: product_request.id, error: "first")
    service.call(product_request_id: product_request.id, error: "second")

    expect(product_request.refresh.error).to eq("first")
  end
end
