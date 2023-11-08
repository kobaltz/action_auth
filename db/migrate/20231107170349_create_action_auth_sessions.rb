class CreateActionAuthSessions < ActiveRecord::Migration[7.1]
  def change
    create_table :action_auth_sessions do |t|
      t.references :action_auth_user, null: false, foreign_key: true
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end
  end
end
