require "test_helper"

module ActionAuth
  class UsersControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = sign_in_as(action_auth_users(:one))
    end

    test "destroys user" do
      assert_difference("User.count", -1) do
        delete users_url(@user)
      end

      assert_response :redirect
      follow_redirect!
      assert_match "Your account has been deleted.", response.body
    end
  end
end
