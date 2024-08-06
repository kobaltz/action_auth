class AddWebauthnIdToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :webauthn_id, :string
  end
end
