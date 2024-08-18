class AddTypeToWebauthnCredentials < ActiveRecord::Migration[7.2]
  def change
    add_column :webauthn_credentials, :key_type, :integer, default: 0, limit: 2
  end
end
