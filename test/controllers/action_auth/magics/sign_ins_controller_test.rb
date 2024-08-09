require "test_helper"

module ActionAuth
  class Magics::SignInsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should sign in user with valid token" do
      user = action_auth_users(:one)
      valid_token = user.generate_token_for(:magic_token)
      assert_difference("Session.count", 1) do
        get magics_sign_ins_url(token: valid_token)
      end
      assert user.reload.verified
    end

    test "should not sign in user with invalid token" do
      assert_difference("Session.count", 0) do
        get magics_sign_ins_url(token: 'invalid_token')
      end

      assert_redirected_to sign_in_path
    end
  end
end
