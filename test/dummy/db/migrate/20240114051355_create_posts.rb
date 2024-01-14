class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.belongs_to :user, null: false, foreign_key: { to_table: :action_auth_users }
      t.string :title

      t.timestamps
    end
  end
end
