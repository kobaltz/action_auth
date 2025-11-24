require "test_helper"

module ActionAuth
  class PasswordsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = sign_in_as(action_auth_users(:one))
    end

    test "should get edit" do
      get edit_password_path
      assert_response :success
    end

    test "should update password" do
      patch password_path, params: { password_challenge: "123456789012", password: "MyV3ry$ecureP@ssw0rd!", password_confirmation: "MyV3ry$ecureP@ssw0rd!" }
      assert_response :redirect
    end

    test "should not update password with wrong password challenge" do
      patch password_path, params: { password_challenge: "SecretWrong1*3", password: "MyV3ry$ecureP@ssw0rd!", password_confirmation: "MyV3ry$ecureP@ssw0rd!" }

      assert_response :unprocessable_entity
      assert_select "li", /Password challenge is invalid/
    end
  end
end
