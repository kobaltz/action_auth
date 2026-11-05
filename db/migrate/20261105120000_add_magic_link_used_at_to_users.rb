class AddMagicLinkUsedAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :magic_link_used_at, :datetime
  end
end
