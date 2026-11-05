require "test_helper"

module ActionAuth
  class Magics::SignInsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    INVALID_LINK = Magics::SignInsController::INVALID_LINK

    setup do
      @user = action_auth_users(:one)
    end

    def magic_token(user = @user)
      user.reload.generate_token_for(:magic_token)
    end

    def assert_link_refused(token)
      assert_no_difference("Session.count") { post magics_sign_ins_url, params: { token: token } }

      assert_response :see_other
      assert_redirected_to sign_in_path
      assert_equal INVALID_LINK, flash[:alert]
    end

    test "opening a link only asks for confirmation, however many times it's opened" do
      @user.update!(verified: false)
      token = magic_token

      assert_no_difference("Session.count") do
        3.times { get magics_sign_ins_url(token: token) }
      end

      assert_response :success
      assert_select "form[action=?][method=post]", magics_sign_ins_path do
        assert_select "input[name=token][value=?]", token
        assert_select "button", "Sign in"
      end
      assert_not @user.reload.verified
      assert_nil @user.magic_link_used_at
      assert_signed_out
    end

    test "the confirmation page says which account is signing in" do
      get magics_sign_ins_url(token: magic_token)

      assert_select "strong", @user.email
    end

    test "confirming signs in and verifies the email" do
      @user.update!(verified: false)

      assert_difference -> { @user.sessions.count }, 1 do
        post magics_sign_ins_url, params: { token: magic_token }
      end

      assert_redirected_to "/"
      assert @user.reload.verified
      assert_signed_in
    end

    test "a link still works after a scanner has opened it" do
      token = magic_token
      2.times { get magics_sign_ins_url(token: token) }

      assert_difference("Session.count", 1) { post magics_sign_ins_url, params: { token: token } }
    end

    test "sends people to the configured path" do
      with_action_auth_config(after_sign_in_path: -> { "/dashboard" }) do
        post magics_sign_ins_url, params: { token: magic_token }
      end

      assert_redirected_to "/dashboard"
    end

    test "a link only works once" do
      token = magic_token
      post magics_sign_ins_url, params: { token: token }
      assert_signed_in

      assert_link_refused(token)
    end

    test "a used link is refused when opened, without showing the confirmation" do
      token = magic_token
      post magics_sign_ins_url, params: { token: token }

      get magics_sign_ins_url(token: token)

      assert_redirected_to sign_in_path
      assert_equal INVALID_LINK, flash[:alert]
    end

    test "signing out doesn't bring a used link back" do
      token = magic_token
      post magics_sign_ins_url, params: { token: token }
      delete session_url(@user.sessions.last)
      assert_signed_out

      assert_link_refused(token)
    end

    test "using one link uses up the others already sent" do
      first = magic_token
      second = magic_token
      post magics_sign_ins_url, params: { token: first }

      assert_link_refused(second)
    end

    test "either of two links can be the one that's used" do
      older = magic_token
      travel 1.minute
      magic_token

      assert_difference("Session.count", 1) { post magics_sign_ins_url, params: { token: older } }
    end

    test "a new link works after an earlier one was used" do
      post magics_sign_ins_url, params: { token: magic_token }
      travel 1.minute

      assert_difference("Session.count", 1) { post magics_sign_ins_url, params: { token: magic_token } }
    end

    test "an invalid token does not sign in" do
      get magics_sign_ins_url(token: "invalid_token")
      assert_redirected_to sign_in_path
      assert_equal INVALID_LINK, flash[:alert]

      assert_link_refused("invalid_token")
    end

    test "a missing or non-string token does not sign in" do
      [{}, { token: ["x"] }, { token: { a: "b" } }].each do |params|
        assert_no_difference("Session.count", "for #{params.inspect}") do
          get magics_sign_ins_url, params: params
          assert_redirected_to sign_in_path

          post magics_sign_ins_url, params: params
          assert_redirected_to sign_in_path
        end
      end
    end

    test "an expired link does not sign in" do
      token = magic_token

      travel 21.minutes do
        get magics_sign_ins_url(token: token)
        assert_redirected_to sign_in_path

        assert_link_refused(token)
      end
    end

    test "changing the password invalidates outstanding links" do
      token = magic_token
      @user.update!(password: STRONG_PASSWORD)

      assert_link_refused(token)
    end

    test "changing the email invalidates links sent to the old address" do
      token = magic_token
      @user.update!(email: "new_address@example.com")

      assert_link_refused(token)
      assert_not @user.reload.verified
    end

    test "an account with a security key still has to use it" do
      user, client = create_user_with_authenticator

      assert_no_difference("Session.count") do
        post magics_sign_ins_url, params: { token: magic_token(user) }
      end

      assert_redirected_to new_webauthn_credential_authentications_url
      assert_signed_out

      get new_webauthn_credential_authentications_url
      post_webauthn webauthn_credential_authentications_url, client.get(challenge: webauthn_options_on_page["challenge"])

      assert_response :success
      assert_signed_in
    end

    test "getting as far as the security key step still uses up the link" do
      user, = create_user_with_authenticator
      token = magic_token(user)
      post magics_sign_ins_url, params: { token: token }

      assert_link_refused(token)
    end
  end
end
