require "test_helper"

module ActionAuth
  class Magics::SignInsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
    end

    test "a valid link signs in and verifies the email" do
      assert_difference -> { @user.sessions.count }, 1 do
        get magics_sign_ins_url(token: @user.generate_token_for(:magic_token))
      end

      assert_redirected_to "/"
      assert @user.reload.verified
      assert_signed_in
    end

    test "sends people to the configured path" do
      with_action_auth_config(after_sign_in_path: -> { "/dashboard" }) do
        get magics_sign_ins_url(token: @user.generate_token_for(:magic_token))
      end

      assert_redirected_to "/dashboard"
    end

    test "an invalid token does not sign in" do
      assert_no_difference("Session.count") do
        get magics_sign_ins_url(token: "invalid_token")
      end

      assert_redirected_to sign_in_path
      assert_equal "Authentication failed, please try again.", flash[:alert]
    end

    test "a missing or non-string token does not sign in" do
      [{}, { token: ["x"] }, { token: { a: "b" } }].each do |params|
        assert_no_difference("Session.count", "for #{params.inspect}") do
          get magics_sign_ins_url, params: params
        end

        assert_redirected_to sign_in_path
      end
    end

    test "an expired link does not sign in" do
      token = @user.generate_token_for(:magic_token)

      travel 21.minutes do
        assert_no_difference("Session.count") { get magics_sign_ins_url(token: token) }
      end
    end

    test "changing the password invalidates outstanding links" do
      token = @user.generate_token_for(:magic_token)
      @user.update!(password: STRONG_PASSWORD)

      assert_no_difference("Session.count") { get magics_sign_ins_url(token: token) }
    end

    test "an account with a security key still has to use it" do
      user, client = create_user_with_authenticator

      assert_no_difference("Session.count") do
        get magics_sign_ins_url(token: user.generate_token_for(:magic_token))
      end

      assert_redirected_to new_webauthn_credential_authentications_url
      assert_signed_out

      get new_webauthn_credential_authentications_url
      post_webauthn webauthn_credential_authentications_url, client.get(challenge: webauthn_options_on_page["challenge"])

      assert_response :success
      assert_signed_in
    end
  end
end
