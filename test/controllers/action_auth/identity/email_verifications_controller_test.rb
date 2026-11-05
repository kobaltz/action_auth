require "test_helper"

class ActionAuth::Identity::EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: false)
  end

  test "sends a verification email to a known address" do
    post identity_email_verification_url, params: { email: @user.email }

    assert_enqueued_emails 1
    assert_redirected_to sign_in_url
  end

  test "an unknown address gets the same response and no email" do
    post identity_email_verification_url, params: { email: "nobody@example.com" }

    assert_enqueued_emails 0
    assert_redirected_to sign_in_url
    assert_equal "We sent a verification email to your email address", flash[:notice]
  end

  test "a missing or non-string email sends nothing" do
    [{}, { email: ["a@b.co"] }, { email: { a: "b" } }].each do |params|
      Rails.cache.clear
      post identity_email_verification_url, params: params

      assert_redirected_to sign_in_url
    end
    assert_enqueued_emails 0
  end

  test "requests are rate limited" do
    5.times { post identity_email_verification_url, params: { email: @user.email } }

    post identity_email_verification_url, params: { email: @user.email }

    assert_enqueued_emails 5
    assert_equal "Too many requests. Try again later.", flash[:alert]
  end

  test "a valid link verifies the email" do
    sid = @user.generate_token_for(:email_verification)

    get identity_email_verification_url(sid: sid)

    assert_redirected_to sign_in_url
    assert @user.reload.verified
  end

  test "the Verify Email link goes to the form without reporting an error" do
    get identity_email_verification_url

    assert_redirected_to edit_identity_email_url
    assert_nil flash[:alert]
  end

  test "an expired link does not verify" do
    sid = @user.generate_token_for(:email_verification)

    travel 3.days

    get identity_email_verification_url(sid: sid)

    assert_redirected_to edit_identity_email_url
    assert_equal "That email verification link is invalid", flash[:alert]
    assert_not @user.reload.verified
  end

  test "a link for an old address does not verify the new one" do
    sid = @user.generate_token_for(:email_verification)
    @user.update!(email: "changed@example.com")

    get identity_email_verification_url(sid: sid)

    assert_equal "That email verification link is invalid", flash[:alert]
    assert_not @user.reload.verified
  end

  test "a garbage link does not verify" do
    get identity_email_verification_url(sid: "garbage")

    assert_redirected_to edit_identity_email_url
    assert_equal "That email verification link is invalid", flash[:alert]
  end
end
