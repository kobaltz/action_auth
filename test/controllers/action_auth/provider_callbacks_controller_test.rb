require "test_helper"

module ActionAuth
  class ProviderCallbacksControllerTest < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    def mock_oauth(provider: "developer", uid: "12345", **info)
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(provider: provider, uid: uid, info: info)
    end

    # The whole flow as a browser does it: the button, then the provider, then back.
    def sign_in_with_provider(provider = "developer")
      post action_auth.oauth_request_path(provider)
      follow_redirect!
    end

    test "the buttons POST, and keep Turbo out of the way since they redirect to another site" do
      [action_auth.sign_in_path, action_auth.sign_up_path].each do |path|
        get path

        assert_select "form[method=post][action=?][data-turbo=false]", action_auth.oauth_request_path("developer") do
          assert_select "button", "Continue with Developer"
        end
        assert_select "form[action=?]", action_auth.oauth_request_path("other")
      end
    end

    test "no buttons when turned off" do
      with_action_auth_config(oauth_enabled: false) do
        get action_auth.sign_in_path

        assert_select "button", text: /Continue with/, count: 0
      end
    end

    test "a new person gets an account and is signed in" do
      mock_oauth(email: "New.Person@Example.com", name: "New Person")

      assert_difference "User.count", 1 do
        sign_in_with_provider
      end

      assert_redirected_to "/"
      assert_equal "Welcome! You have signed up successfully", flash[:notice]
      assert_signed_in

      user = User.find_by(email: "new.person@example.com")
      assert user.verified
      assert user.password_usable?
      assert_equal "New.Person@Example.com", user.connected_accounts.first.display_name
      assert_equal %w[developer 12345], user.connected_accounts.first.values_at(:provider, :uid)
    end

    test "the new account's password can't be guessed" do
      mock_oauth(email: "new@example.com")

      sign_in_with_provider

      assert User.find_by(email: "new@example.com").password_digest.present?
    end

    test "sends people to the configured path" do
      mock_oauth(email: "new@example.com")

      with_action_auth_config(after_sign_in_path: "/dashboard") do
        sign_in_with_provider
      end

      assert_redirected_to "/dashboard"
    end

    test "a provider that shares no email gets a placeholder, which nothing tries to send mail to" do
      mock_oauth(nickname: "someone")

      assert_no_enqueued_emails do
        sign_in_with_provider
      end

      assert_signed_in
      user = ConnectedAccount.find_by(uid: "12345").user
      assert user.email.end_with?(User::OAUTH_EMAIL_SUFFIX)
      assert_not user.password_usable?
      assert_equal "someone", user.connected_accounts.first.display_name
    end

    test "a very long name is cut to fit the column" do
      mock_oauth(name: "x" * 300)

      sign_in_with_provider

      assert_signed_in
      assert_equal 255, ConnectedAccount.find_by(uid: "12345").display_name.length
    end

    test "an email the provider says is unverified isn't used" do
      mock_oauth(email: "victim@example.com", email_verified: false)

      sign_in_with_provider

      assert_not User.exists?(email: "victim@example.com")
      assert ConnectedAccount.find_by(uid: "12345").user.email.end_with?(User::OAUTH_EMAIL_SUFFIX)
    end

    test "an unverified email can't claim an existing account's address either" do
      existing = action_auth_users(:one)
      mock_oauth(email: existing.email, email_verified: "false")

      sign_in_with_provider

      assert_empty existing.connected_accounts
      assert_not_equal existing.id, ConnectedAccount.find_by(uid: "12345").user_id
    end

    test "something that isn't an email address isn't used" do
      mock_oauth(email: "not an email")

      sign_in_with_provider

      assert ConnectedAccount.find_by(uid: "12345").user.email.end_with?(User::OAUTH_EMAIL_SUFFIX)
    end

    test "matching an existing account's email doesn't sign in to it or connect to it" do
      existing = action_auth_users(:one)
      mock_oauth(email: existing.email.upcase)

      assert_no_difference ["User.count", "ConnectedAccount.count", "Session.count"] do
        sign_in_with_provider
      end

      assert_redirected_to action_auth.sign_in_path
      assert_match "already an account", flash[:alert]
      assert_signed_out
    end

    test "that message doesn't appear for an address nobody has" do
      mock_oauth(email: "new@example.com")

      sign_in_with_provider

      assert_no_match "already an account", flash[:alert].to_s
    end

    test "a connected account signs in, whatever email the provider now reports" do
      user = action_auth_users(:one)
      user.connected_accounts.create!(provider: "developer", uid: "12345")
      mock_oauth(email: "changed@example.com")

      assert_no_difference "User.count" do
        sign_in_with_provider
      end

      assert_redirected_to "/"
      assert_equal user.id, ActionAuth::Session.last.user_id
      assert_signed_in
    end

    test "the same uid at another provider is a different person" do
      user = action_auth_users(:one)
      user.connected_accounts.create!(provider: "other", uid: "12345")
      mock_oauth(provider: "developer", email: "new@example.com")

      sign_in_with_provider

      assert_not_equal user.id, ActionAuth::Session.last.user_id
    end

    test "an unverified email doesn't stop a connected account signing in" do
      user = action_auth_users(:one)
      user.update!(verified: false)
      user.connected_accounts.create!(provider: "developer", uid: "12345")
      mock_oauth

      sign_in_with_provider

      assert_signed_in
    end

    test "a security key is still required" do
      user, = create_user_with_authenticator
      user.connected_accounts.create!(provider: "developer", uid: "12345")
      mock_oauth

      assert_no_difference -> { user.sessions.count } do
        sign_in_with_provider
      end

      assert_redirected_to action_auth.new_webauthn_credential_authentications_path
    end

    test "a suspended account is refused, with the reason" do
      user = action_auth_users(:one)
      user.connected_accounts.create!(provider: "developer", uid: "12345")
      user.suspend_account!
      mock_oauth

      sign_in_with_provider

      assert_redirected_to action_auth.sign_in_path
      assert_equal "This account has been suspended.", flash[:alert]
      assert_signed_out
    end

    test "a locked account can still sign in, and it lifts the lock" do
      user = action_auth_users(:one)
      user.connected_accounts.create!(provider: "developer", uid: "12345")
      user.update_columns(failed_sign_in_attempts: 10, account_locked_at: Time.current)
      mock_oauth

      sign_in_with_provider

      assert_signed_in
      assert_not user.reload.account_locked?
    end

    test "when signed in, it connects to the current account" do
      user = action_auth_users(:one)
      sign_in_as(user)
      mock_oauth(email: "someone.else@example.com", nickname: "someone")

      assert_no_difference ["User.count", "Session.count"] do
        sign_in_with_provider
      end

      assert_redirected_to action_auth.sessions_path
      assert_equal "Developer has been connected to your account.", flash[:notice]
      assert_equal "someone.else@example.com", user.connected_accounts.first.display_name
      assert_equal "john.smith@example.com", user.reload.email, "the provider's address shouldn't replace the account's"
    end

    test "when signed in, connecting one already connected changes nothing" do
      user = action_auth_users(:one)
      user.connected_accounts.create!(provider: "developer", uid: "12345")
      sign_in_as(user)
      mock_oauth

      assert_no_difference "ConnectedAccount.count" do
        sign_in_with_provider
      end

      assert_equal "Developer is already connected to your account.", flash[:notice]
    end

    test "when signed in, an account connected to someone else stays with them" do
      owner = action_auth_users(:two)
      owner.connected_accounts.create!(provider: "developer", uid: "12345")
      user = action_auth_users(:one)
      sign_in_as(user)
      mock_oauth

      sign_in_with_provider

      assert_equal "That Developer account is connected to a different account.", flash[:alert]
      assert_empty user.connected_accounts
      assert_equal owner.id, ConnectedAccount.find_by(uid: "12345").user_id
    end

    test "losing a race to connect is treated like someone else having it" do
      sign_in_as(action_auth_users(:one))
      mock_oauth

      stub_class_method(ConnectedAccount, :find_by, nil) do
        action_auth_users(:two).connected_accounts.create!(provider: "developer", uid: "12345")
        sign_in_with_provider
      end

      assert_equal "That Developer account is connected to a different account.", flash[:alert]
    end

    test "losing a race to sign up doesn't show an error page" do
      mock_oauth(email: "new@example.com")

      stub_class_method(User, :create!, ->(*) { raise ActiveRecord::RecordNotUnique }) do
        sign_in_with_provider
      end

      assert_redirected_to action_auth.sign_in_path
      assert_equal ProviderCallbacksController::FAILED, flash[:alert]
    end

    test "a response with no uid is refused, since it doesn't identify anyone" do
      mock_oauth(uid: "", email: "new@example.com")

      assert_no_difference "User.count" do
        sign_in_with_provider
      end

      assert_equal ProviderCallbacksController::FAILED, flash[:alert]
    end

    test "a response with no uid doesn't connect anything, and isn't blamed on someone else" do
      user = action_auth_users(:one)
      sign_in_as(user)
      mock_oauth(uid: "")

      sign_in_with_provider

      assert_empty user.connected_accounts
      assert_redirected_to action_auth.sessions_path
      assert_equal ProviderCallbacksController::FAILED, flash[:alert]
    end

    test "the callback does nothing without OmniAuth having verified the response" do
      assert_no_difference ["User.count", "ConnectedAccount.count", "Session.count"] do
        get action_auth.oauth_callback_path("not_configured"), params: { email: "new@example.com", uid: "1" }
      end

      assert_redirected_to action_auth.sign_in_path
      assert_equal ProviderCallbacksController::FAILED, flash[:alert]
    end

    test "a response from a provider ActionAuth wasn't given isn't trusted, such as the app's own OmniAuth" do
      auth = OmniAuth::AuthHash.new(provider: "apps_own", uid: "1", info: { email: "new@example.com" })

      assert_no_difference "User.count" do
        get action_auth.oauth_callback_path("apps_own"), env: { "omniauth.auth" => auth }
      end

      assert_redirected_to action_auth.sign_in_path
    end

    test "a failure at the provider goes back with a fixed message" do
      OmniAuth.config.mock_auth[:developer] = :invalid_credentials

      sign_in_with_provider
      assert_redirected_to %r{/action_auth/auth/failure\?message=invalid_credentials}

      follow_redirect!

      assert_redirected_to action_auth.sign_in_path
      assert_equal ProviderCallbacksController::FAILED, flash[:alert]
    end

    test "a failure when signed in goes back to the management screen" do
      sign_in_as(action_auth_users(:one))

      get action_auth.oauth_failure_path

      assert_redirected_to action_auth.sessions_path
    end

    test "the failure message isn't displayed, since anyone can link to it" do
      get action_auth.oauth_failure_path(message: "<script>alert(1)</script>Call this number")
      follow_redirect!

      assert_no_match "Call this number", response.body
    end

    test "a missing CSRF gem is explained in the log" do
      logs = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(logs)

      get action_auth.oauth_failure_path(message: "authenticity_error")

      assert_match "omniauth-rails_csrf_protection", logs.string
    ensure
      Rails.logger = original
    end

    test "callbacks are rate limited" do
      10.times { get action_auth.oauth_callback_path("developer") }

      get action_auth.oauth_callback_path("developer")

      assert_redirected_to action_auth.sign_in_path
      assert_equal "Too many attempts. Try again later.", flash[:alert]
    end

    test "not having run the migration is explained" do
      mock_oauth(email: "new@example.com")

      stub_class_method(ConnectedAccount, :table_exists?, false) do
        post action_auth.oauth_request_path("developer")

        error = assert_raises(RuntimeError) { follow_redirect! }
        assert_match "action_auth:install:migrations", error.message
      end
    end

    class RequestPhase < ActionDispatch::IntegrationTest
      setup { OmniAuth.config.test_mode = false }
      teardown { OmniAuth.config.test_mode = true }

      test "the strategy's real paths follow the engine's mount point" do
        post action_auth.oauth_request_path("developer")

        assert_response :success
        assert_select "form[action=?]", "/action_auth/auth/developer/callback"
      end

      test "every configured provider gets its own path" do
        post action_auth.oauth_request_path("other")

        assert_select "form[action=?]", "/action_auth/auth/other/callback"
      end

      test "the real strategy's response creates an account" do
        get "/action_auth/auth/developer/callback", params: { name: "New Person", email: "new@example.com" }

        assert_redirected_to "/"
        assert_signed_in
        assert User.exists?(email: "new@example.com")
      end

      test "it can't be started with a GET, so a link on another site can't start it" do
        get "/action_auth/auth/developer"

        assert_response :not_found
      end

      test "a provider that isn't configured goes nowhere" do
        post action_auth.oauth_request_path("not_configured")

        assert_redirected_to action_auth.sign_in_path
        assert_equal ProviderCallbacksController::FAILED, flash[:alert]
      end

      class WithForgeryProtection < ActionDispatch::IntegrationTest
        setup do
          OmniAuth.config.test_mode = false
          @original = ActionController::Base.allow_forgery_protection
          ActionController::Base.allow_forgery_protection = true
        end

        teardown do
          OmniAuth.config.test_mode = true
          ActionController::Base.allow_forgery_protection = @original
        end

        test "starting without the form's token is refused" do
          post action_auth.oauth_request_path("developer")

          assert_redirected_to %r{/action_auth/auth/failure}
          follow_redirect!

          assert_redirected_to action_auth.sign_in_path
          assert_equal ProviderCallbacksController::FAILED, flash[:alert]
        end

        test "the button's own token is accepted" do
          get action_auth.sign_in_path
          form = css_select("form[action='#{action_auth.oauth_request_path("developer")}']").first
          token = form.at_css("input[name=authenticity_token]")["value"]

          post action_auth.oauth_request_path("developer"), params: { authenticity_token: token }

          assert_response :success
          assert_select "form[action=?]", "/action_auth/auth/developer/callback"
        end
      end
    end
  end
end
