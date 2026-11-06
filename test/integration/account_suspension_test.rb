require "test_helper"

class AccountSuspensionTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SUSPENDED = "This account has been suspended.".freeze

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: true)
  end

  test "is on by default" do
    assert ActionAuth::Configuration.new.account_suspension_enabled?
  end

  test "the right password is told, and doesn't get a session" do
    @user.suspend_account!

    assert_no_difference -> { @user.sessions.count } do
      post action_auth.sign_in_path, params: { email: @user.email, password: FIXTURE_PASSWORD }
    end

    assert_redirected_to action_auth.sign_in_path
    assert_equal SUSPENDED, flash[:alert]
    assert_signed_out
  end

  test "the wrong password isn't told, so this doesn't reveal who's suspended" do
    @user.suspend_account!

    post action_auth.sign_in_path, params: { email: @user.email, password: "not the password" }

    assert_equal "That email or password is incorrect", flash[:alert]
  end

  test "suspending ends every session" do
    sign_in_as(@user)
    @user.sessions.create!
    assert_signed_in

    @user.suspend_account!

    assert_equal 0, @user.sessions.count
    assert_signed_out
  end

  test "a suspension set directly still ends a session on its next request, on the app's own pages too" do
    current = sign_in_as(@user)
    @user.update_columns(account_suspended_at: Time.current)

    get "/posts"

    assert_redirected_to action_auth.sign_in_path
    assert_equal SUSPENDED, flash[:alert]
    assert_equal "", cookies["session_token"]
    assert_not ActionAuth::Session.exists?(current.id)
  end

  test "ending a session this way only happens once" do
    sign_in_as(@user)
    @user.update_columns(account_suspended_at: Time.current)

    get "/"
    assert_redirected_to action_auth.sign_in_path

    get "/"
    assert_response :success
  end

  test "unsuspended accounts aren't touched" do
    sign_in_as(@user)

    get "/"

    assert_response :success
  end

  test "no session can be created for a suspended account, whatever the code path" do
    @user.suspend_account!

    assert_raises(ActiveRecord::RecordInvalid) { @user.sessions.create! }
  end

  test "unsuspending lets the account sign in again" do
    @user.suspend_account!
    @user.unsuspend_account!

    post action_auth.sign_in_path, params: { email: @user.email, password: FIXTURE_PASSWORD }

    assert_signed_in
  end

  test "an account that no longer passes validation can still be suspended" do
    @user.update_columns(email: "no longer valid")

    @user.suspend_account!

    assert @user.reload.account_suspended?
  end

  test "being suspended doesn't change the sign up form's answer" do
    @user.suspend_account!

    assert_no_difference "ActionAuth::User.count" do
      post action_auth.sign_up_path, params: { email: @user.email, password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }
    end

    assert_response :unprocessable_entity
  end

  test "a magic link isn't sent, and the form's answer is the same" do
    post action_auth.magics_requests_path, params: { email: action_auth_users(:two).email }
    expected = flash[:notice]
    clear_enqueued_jobs

    @user.suspend_account!

    assert_no_enqueued_emails do
      post action_auth.magics_requests_path, params: { email: @user.email }
    end

    assert_equal expected, flash[:notice]
    assert_redirected_to action_auth.sign_in_path
  end

  test "a magic link sent before the suspension doesn't work" do
    token = @user.generate_token_for(:magic_token)
    @user.suspend_account!

    post action_auth.magics_sign_ins_path, params: { token: token }

    assert_equal SUSPENDED, flash[:alert]
    assert_signed_out
  end

  test "a password reset isn't sent, and the form's answer is the same" do
    post action_auth.identity_password_reset_path, params: { email: action_auth_users(:two).email }
    expected = flash[:notice]
    clear_enqueued_jobs

    @user.suspend_account!

    assert_no_enqueued_emails do
      post action_auth.identity_password_reset_path, params: { email: @user.email }
    end

    assert_equal expected, flash[:notice]
  end

  test "a password reset link sent before the suspension doesn't work" do
    token = @user.generate_token_for(:password_reset)
    @user.suspend_account!

    get action_auth.edit_identity_password_reset_path(sid: token)
    assert_redirected_to action_auth.new_identity_password_reset_path

    patch action_auth.identity_password_reset_path, params: { sid: token, password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }
    assert_redirected_to action_auth.new_identity_password_reset_path

    assert_not @user.reload.authenticate(STRONG_PASSWORD)
  end

  test "an SMS code isn't sent, and the form's answer is the same" do
    @user.update!(phone_number: "+11234567890")
    @user.suspend_account!

    stub_class_method(SmsSender, :send_code, ->(*) { flunk "shouldn't send a code" }) do
      post action_auth.sms_auths_requests_path, params: { phone_number: @user.phone_number }
    end

    assert_redirected_to action_auth.sms_auths_sign_ins_path
    assert_equal "Check your phone for a SMS Code.", flash[:notice]
  end

  test "an SMS code sent before the suspension doesn't work" do
    @user.update!(phone_number: "+11234567890")
    post action_auth.sms_auths_requests_path, params: { phone_number: @user.phone_number }
    code = @user.reload.sms_code

    @user.suspend_account!
    post action_auth.sms_auths_sign_ins_path, params: { sms_code: code }

    assert_equal SUSPENDED, flash[:alert]
    assert_signed_out
  end

  test "a passkey is refused, with the reason" do
    user, client = create_user_with_authenticator(email: "passkey@example.com")
    user.suspend_account!

    get action_auth.new_sessions_passkey_path
    post_webauthn action_auth.sessions_passkeys_path, client.get(challenge: webauthn_options_on_page["challenge"], user_verified: true)

    assert_response :unprocessable_entity
    assert_equal SUSPENDED, response.body
    assert_signed_out
  end

  test "suspending in the middle of a two step sign in stops it" do
    user, client = create_user_with_authenticator(email: "passkey@example.com")
    post action_auth.sign_in_path, params: { email: user.email, password: STRONG_PASSWORD }
    follow_redirect!
    assertion = client.get(challenge: webauthn_options_on_page["challenge"])

    user.suspend_account!
    post_webauthn action_auth.webauthn_credential_authentications_path, assertion

    assert_redirected_to action_auth.sign_in_path
    assert_signed_out
  end

  test "an account can't be suspended if it wouldn't take effect, and says why" do
    with_action_auth_config(account_suspension_enabled: false) do
      error = assert_raises(RuntimeError) { @user.suspend_account! }

      assert_match "config.account_suspension_enabled", error.message
      assert_nil @user.reload.account_suspended_at
    end
  end

  test "turning it off ignores existing suspensions" do
    @user.update_columns(account_suspended_at: Time.current)

    with_action_auth_config(account_suspension_enabled: false) do
      assert_not @user.account_suspended?

      post action_auth.sign_in_path, params: { email: @user.email, password: FIXTURE_PASSWORD }

      assert_signed_in
    end
  end
end
