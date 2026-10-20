# frozen_string_literal: true

require_relative "../../../app/jobs/create_product"

RSpec.describe Jobs::CreateProduct, :aggregate_failures do
  let(:product_request) { create_product_request(user: create_user) }

  it "fulfills the request when performed" do
    described_class.new.perform(product_request.id)

    expect(product_request.refresh.status).to eq("completed")
  end

  it "retries 5 times (D47)" do
    expect(described_class.get_sidekiq_options["retry"]).to eq(5)
  end

  it "fails the request with creation_failed when retries are exhausted" do
    described_class.sidekiq_retries_exhausted_block.call({ "args" => [product_request.id] }, StandardError.new)
    product_request.refresh

    expect(product_request.status).to eq("failed")
    expect(product_request.error).to eq("creation_failed")
  end
end
