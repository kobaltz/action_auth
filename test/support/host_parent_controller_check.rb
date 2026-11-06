# Run by test/integration/host_parent_controller_test.rb in a separate process,
# because parent_controller is read once, when the controllers load. In this mode
# the dummy app's ApplicationController requires sign in for everything, and is
# ActionAuth's parent. That's how many real apps are set up.
require "test_helper"

class HostParentControllerCheck < ActionDispatch::IntegrationTest
  test "the parent controller is the app's" do
    assert_equal ::ApplicationController, ActionAuth::ApplicationController.superclass
    assert_operator ActionAuth::WebauthnCredentialAuthenticationsController, :<, ::ApplicationController
  end

  test "the app's own pages still require sign in" do
    get "/"

    assert_redirected_to action_auth.sign_in_path
  end

  test "public screens are reachable and use the app's helpers" do
    [
      action_auth.sign_in_path,
      action_auth.sign_up_path,
      action_auth.new_identity_password_reset_path,
      action_auth.edit_identity_email_path,
      action_auth.new_magics_requests_path,
      action_auth.new_sms_auths_requests_path,
      action_auth.new_sessions_passkey_path
    ].each do |path|
      get path

      assert_response :success, "for #{path}"
      assert_select "title", { text: "Dummy Host App" }, "for #{path}"
    end
  end

  test "screens opened from an emailed link are reachable while signed out, and use the app's helpers" do
    user = action_auth_users(:one)
    user.update!(verified: false)

    [
      action_auth.identity_email_verification_path(sid: user.generate_token_for(:email_verification)),
      action_auth.edit_identity_password_reset_path(sid: user.generate_token_for(:password_reset)),
      action_auth.magics_sign_ins_path(token: user.generate_token_for(:magic_token))
    ].each do |path|
      get path

      assert_response :success, "for #{path}"
      assert_select "title", { text: "Dummy Host App" }, "for #{path}"
    end
  end

  test "coming back from an OAuth provider works while signed out" do
    OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(provider: "developer", uid: "1", info: { email: "new@example.com" })

    post action_auth.oauth_request_path("developer")
    follow_redirect!

    assert_redirected_to "/"
    get "/"
    assert_response :success
  end

  test "screens that need sign in still require it" do
    [action_auth.sessions_path, action_auth.edit_password_path, action_auth.new_webauthn_credential_path].each do |path|
      get path

      assert_redirected_to action_auth.sign_in_path, "for #{path}"
    end
  end

  test "the whole two step sign in works" do
    user, client = create_user_with_authenticator

    post action_auth.sign_in_path, params: { email: user.email, password: STRONG_PASSWORD }
    assert_redirected_to action_auth.new_webauthn_credential_authentications_path

    follow_redirect!
    assert_response :success

    post_webauthn action_auth.webauthn_credential_authentications_path,
      client.get(challenge: webauthn_options_on_page["challenge"])
    assert_response :success

    get "/"
    assert_response :success
  end
end
