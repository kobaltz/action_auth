require "test_helper"

module ActionAuth
  class ConnectedAccountsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = action_auth_users(:one)
      @connected_account = @user.connected_accounts.create!(provider: "developer", uid: "12345", display_name: "someone@example.com")
    end

    def make_placeholder_account
      @user.update_columns(email: "#{SecureRandom.hex(32)}#{User::OAUTH_EMAIL_SUFFIX}")
    end

    test "the management screen lists what's connected, and offers the rest" do
      sign_in_as(@user)

      get action_auth.sessions_path

      assert_select "tr#connected_account_#{@connected_account.id}" do
        assert_select "td", "Developer"
        assert_select "td", "someone@example.com"
        assert_select "form[action=?]", action_auth.connected_account_path(@connected_account)
      end

      assert_select "button", text: "Connect Developer", count: 0
      assert_select "form[action=?][data-turbo=false]", action_auth.oauth_request_path("other") do
        assert_select "button", "Connect Other"
      end
    end

    test "a provider that's since been removed from the config can still be seen and disconnected" do
      gone = @user.connected_accounts.create!(provider: "old_provider", uid: "1")
      sign_in_as(@user)

      get action_auth.sessions_path

      assert_select "tr#connected_account_#{gone.id} td", "Old Provider"
    end

    test "the section is hidden when OAuth is off" do
      sign_in_as(@user)

      with_action_auth_config(oauth_enabled: false) do
        get action_auth.sessions_path

        assert_response :success
        assert_select "h2", text: "Connected Accounts", count: 0
      end
    end

    test "the screen still works before the migration has run" do
      sign_in_as(@user)

      stub_class_method(ConnectedAccount, :table_exists?, false) do
        get action_auth.sessions_path

        assert_response :success
        assert_select "h2", text: "Connected Accounts", count: 0
      end
    end

    test "disconnecting requires sign in" do
      assert_no_difference "ConnectedAccount.count" do
        delete action_auth.connected_account_path(@connected_account)
      end

      assert_redirected_to action_auth.sign_in_path
    end

    test "disconnects" do
      sign_in_as(@user)

      assert_difference "ConnectedAccount.count", -1 do
        delete action_auth.connected_account_path(@connected_account)
      end

      assert_redirected_to action_auth.sessions_path
      assert_response :see_other
      assert_equal "Developer has been disconnected.", flash[:notice]
    end

    test "can't disconnect someone else's" do
      sign_in_as(action_auth_users(:two))

      assert_no_difference "ConnectedAccount.count" do
        delete action_auth.connected_account_path(@connected_account)
      end

      assert_response :not_found
    end

    test "can't disconnect the only way into an account" do
      make_placeholder_account
      sign_in_as(@user)

      assert_no_difference "ConnectedAccount.count" do
        delete action_auth.connected_account_path(@connected_account)
      end

      assert_match "only way to sign in", flash[:alert]
    end

    test "can disconnect when another provider is connected" do
      make_placeholder_account
      @user.connected_accounts.create!(provider: "other", uid: "12345")
      sign_in_as(@user)

      assert_difference "ConnectedAccount.count", -1 do
        delete action_auth.connected_account_path(@connected_account)
      end
    end

    test "can disconnect when the account has a phone number and SMS is on" do
      make_placeholder_account
      @user.update_columns(phone_number: "+11234567890")
      sign_in_as(@user)

      assert_difference "ConnectedAccount.count", -1 do
        delete action_auth.connected_account_path(@connected_account)
      end
    end

    test "a phone number doesn't count when SMS is off" do
      make_placeholder_account
      @user.update_columns(phone_number: "+11234567890")
      sign_in_as(@user)

      with_action_auth_config(sms_auth_enabled: false) do
        assert_no_difference "ConnectedAccount.count" do
          delete action_auth.connected_account_path(@connected_account)
        end
      end
    end

    test "can disconnect when a passkey can sign in without a password" do
      user, = create_user_with_authenticator
      connected_account = user.connected_accounts.create!(provider: "developer", uid: "67890")
      user.update_columns(email: "#{SecureRandom.hex(32)}#{User::OAUTH_EMAIL_SUFFIX}")
      sign_in_as(user)

      assert_difference "ConnectedAccount.count", -1 do
        delete action_auth.connected_account_path(connected_account)
      end
    end

    test "a security key that can't sign in by itself doesn't count" do
      user, = create_user_with_authenticator
      connected_account = user.connected_accounts.create!(provider: "developer", uid: "67890")
      user.update_columns(email: "#{SecureRandom.hex(32)}#{User::OAUTH_EMAIL_SUFFIX}")
      sign_in_as(user)

      with_action_auth_config(passkey_only: false) do
        assert_no_difference "ConnectedAccount.count" do
          delete action_auth.connected_account_path(connected_account)
        end
      end
    end

    test "deleting a user removes what's connected" do
      assert_difference "ConnectedAccount.count", -1 do
        @user.destroy
      end
    end

    test "an account with no email or password can delete itself soon after signing in through the provider" do
      make_placeholder_account
      sign_in_as(@user)

      assert_difference "User.count", -1 do
        delete action_auth.users_path
      end
    end

    test "the same account isn't offered links that ask for a password it can't know" do
      make_placeholder_account
      sign_in_as(@user)

      get action_auth.sessions_path

      assert_select "a", text: "Change email", count: 0
      assert_select "a", text: "Change password", count: 0
    end

    test "the same account is told how to prove it's them, and not to use SMS" do
      make_placeholder_account
      session = sign_in_as(@user)
      session.update_columns(created_at: 1.hour.ago)

      get action_auth.sessions_path
      assert_match "your connected account", response.body
      assert_no_match "SMS", response.body

      assert_no_difference "User.count" do
        delete action_auth.users_path
      end

      assert_match "your connected account", flash[:alert]
    end
  end
end
