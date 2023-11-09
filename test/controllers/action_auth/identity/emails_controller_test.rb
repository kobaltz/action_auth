require "test_helper"

class ActionAuth::Identity::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  setup do
    @user = action_auth_users(:one)
    sign_in_as(@user)
  end

  test "should get edit" do
    get edit_identity_email_url
    assert_response :success
  end

  test "should update email" do
    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: "123456789012" }
    assert_response :redirect
  end


  test "should not update email with wrong password challenge" do
    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: "SecretWrong1*3" }

    assert_response :unprocessable_entity
    assert_match "Password challenge is invalid", response.body
  end
end
