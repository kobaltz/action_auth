class AddWebauthnCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :action_auth_webauthn_credentials do |t|
      t.string :external_id, null: false
      t.string :public_key, null: false
      t.string :nickname, null: false
      t.bigint :sign_count, null: false, default: 0

      t.index :external_id, unique: true

      t.references :action_auth_user, foreign_key: true

      t.timestamps
    end
  end
end
