class AddAccountLockoutAndSuspensionToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :failed_sign_in_attempts, :integer, null: false, default: 0
    add_column :users, :account_locked_at, :datetime
    add_column :users, :account_suspended_at, :datetime
  end
end
