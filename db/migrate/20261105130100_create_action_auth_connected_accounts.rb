class CreateActionAuthConnectedAccounts < ActiveRecord::Migration[7.2]
  def change
    # Copied from the existing column, because an app's users.id isn't always a
    # bigint, and a foreign key of another type is refused by some databases.
    user_id_type = columns(:users).find { |column| column.name == "id" }.sql_type

    create_table :action_auth_connected_accounts do |t|
      # Cascades so that deleting a user works even if OAuth has since been turned off.
      t.references :user, null: false, type: user_id_type, foreign_key: { on_delete: :cascade }
      t.string :provider, null: false
      t.string :uid, null: false
      t.string :display_name

      t.timestamps

      t.index [:provider, :uid], unique: true
    end
  end
end
