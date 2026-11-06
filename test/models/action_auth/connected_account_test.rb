require "test_helper"

module ActionAuth
  class ConnectedAccountTest < ActiveSupport::TestCase
    setup { @user = action_auth_users(:one) }

    test "needs a provider and a uid" do
      assert_not ConnectedAccount.new(user: @user, provider: "", uid: "1").valid?
      assert_not ConnectedAccount.new(user: @user, provider: "github", uid: "").valid?
    end

    test "one account at a provider can only connect once" do
      @user.connected_accounts.create!(provider: "github", uid: "1")

      assert_not action_auth_users(:two).connected_accounts.new(provider: "github", uid: "1").valid?
      assert action_auth_users(:two).connected_accounts.new(provider: "google_oauth2", uid: "1").valid?
    end

    test "the database enforces that too, for simultaneous requests" do
      @user.connected_accounts.create!(provider: "github", uid: "1")
      duplicate = action_auth_users(:two).connected_accounts.new(provider: "github", uid: "1")

      assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
    end

    test "labels come from the config, then from the provider's name" do
      assert_equal "Developer", @user.connected_accounts.new(provider: "developer").provider_label
      assert_equal "Old Provider", @user.connected_accounts.new(provider: "old_provider").provider_label
    end
  end
end
