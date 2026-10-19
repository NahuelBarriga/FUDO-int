# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:users) do
      primary_key :id, :uuid, default: Sequel.function(:uuidv7)
      column :username, :text, null: false
      column :password_digest, :text, null: false
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index Sequel.function(:lower, :username), unique: true, name: :users_username_lower_index
    end
  end
end
