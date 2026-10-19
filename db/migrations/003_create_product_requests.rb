# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:product_requests) do
      primary_key :id, :uuid, default: Sequel.function(:uuidv7)
      foreign_key :user_id, :users, type: :uuid, null: false
      column :name, :text, null: false
      column :status, :text, null: false, default: "pending"
      foreign_key :product_id, :products, type: :uuid, unique: true
      column :error, :text
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:product_requests_status_check, status: %w[pending completed failed])
      constraint(:product_requests_completed_has_product,
                 Sequel.lit("(status = 'completed') = (product_id IS NOT NULL)"))
      constraint(:product_requests_failed_has_error,
                 Sequel.lit("(status = 'failed') = (error IS NOT NULL)"))
    end
  end
end
