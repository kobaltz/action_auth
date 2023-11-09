require "test_helper"

class ActionAuth::Identity::EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  setup do
    @user = action_auth_users(:one)
    sign_in_as(@user)
    @user.update!(verified: false)
  end

  test "should send a verification email" do
    post identity_email_verification_url
    assert_redirected_to "/"
  end

  test "should verify email" do
    sid = @user.generate_token_for(:email_verification)

    get identity_email_verification_url(sid: sid, email: @user.email)
    assert_redirected_to "/"
  end

  test "should not verify email with expired token" do
    sid = @user.generate_token_for(:email_verification)

    travel 3.days

    get identity_email_verification_url(sid: sid, email: @user.email)

    assert_redirected_to edit_identity_email_url
    assert_equal "That email verification link is invalid", flash[:alert]
  end
end
