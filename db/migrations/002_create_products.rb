# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:products) do
      primary_key :id, :uuid, default: Sequel.function(:uuidv7)
      foreign_key :user_id, :users, type: :uuid, null: false
      column :name, :text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index [:user_id, Sequel.function(:lower, :name)], unique: true, name: :products_user_id_lower_name_index
    end
  end
end
