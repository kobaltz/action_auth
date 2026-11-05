require "test_helper"

module ActionAuth
  class UsersControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
    end

    test "requires sign in" do
      assert_no_difference("User.count") { delete users_url }

      assert_redirected_to sign_in_url
    end

    test "deletes only the signed in user, their sessions and their cookie" do
      session = sign_in_as(@user)

      assert_difference("User.count", -1) do
        delete users_url
      end

      assert_response :see_other
      assert_equal "", cookies["session_token"]
      assert_not User.exists?(@user.id)
      assert_not Session.exists?(session.id)
      assert User.exists?(action_auth_users(:two).id)

      follow_redirect!
      assert_match "Your account has been deleted.", response.body
    end

    test "deleting an account removes its security keys" do
      user, = create_user_with_authenticator
      sign_in_as(user)

      assert_difference("WebauthnCredential.count", -1) { delete users_url }
    end

    test "goes to the configured path" do
      sign_in_as(@user)

      with_action_auth_config(after_sign_out_path: "/goodbye") { delete users_url }

      assert_redirected_to "/goodbye"
    end
  end
end
