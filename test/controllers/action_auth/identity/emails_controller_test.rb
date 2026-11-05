require "test_helper"

class ActionAuth::Identity::EmailsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: true)
  end

  test "edit shows a logged out visitor the verification form" do
    get edit_identity_email_url

    assert_response :success
    assert_select "h1", "Verify Your Email"
    assert_select "form[action=?]", identity_email_verification_path
  end

  test "edit gives a signed in user everything the change needs" do
    sign_in_as(@user)

    get edit_identity_email_url

    assert_select "h1", "Change Your Email"
    assert_select "form[action=?]", identity_email_path do
      assert_select "input[name=email]"
      assert_select "input[name=password_challenge]"
    end
  end

  test "an unverified user can fix a mistyped email or ask for the link again" do
    @user.update!(verified: false)
    sign_in_as(@user)

    get edit_identity_email_url

    assert_select "form[action=?] input[name=password_challenge]", identity_email_path
    assert_select "form[action=?][method=post]", identity_email_verification_path do
      assert_select "input[name=email][value=?]", @user.email
    end
  end

  test "no form is nested inside another" do
    sign_in_as(@user.tap { |user| user.update!(verified: false) })

    get edit_identity_email_url

    assert_select "form form", count: 0
  end

  test "update requires sign in" do
    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: FIXTURE_PASSWORD }

    assert_redirected_to sign_in_url
  end

  test "should update email, require verifying it and send the link" do
    sign_in_as(@user)

    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: FIXTURE_PASSWORD }

    assert_redirected_to sessions_url
    assert_match "Check your email", flash[:notice]
    @user.reload
    assert_equal "new_email@hey.com", @user.email
    assert_not @user.verified
    assert_enqueued_emails 1
    assert_signed_in
  end

  test "submitting the same email doesn't send a verification" do
    sign_in_as(@user)

    patch identity_email_url, params: { email: @user.email, password_challenge: FIXTURE_PASSWORD }

    assert_redirected_to sessions_url
    assert @user.reload.verified
    assert_enqueued_emails 0
  end

  test "should not update email with wrong password challenge" do
    sign_in_as(@user)

    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: "SecretWrong1*3" }

    assert_response :unprocessable_entity
    assert_match "Password challenge is invalid", response.body
    assert_select "input[name=email][value=?]", "new_email@hey.com"
    @user.reload
    assert_equal "john.smith@example.com", @user.email
    assert @user.verified
  end

  test "a rejected change doesn't show the rejected address as the account's" do
    @user.update!(verified: false)
    sign_in_as(@user)

    patch identity_email_url, params: { email: "typo@hey.com", password_challenge: "SecretWrong1*3" }

    assert_select "p", text: /#{@user.email} hasn't been verified/
  end

  test "the challenge can't be skipped" do
    sign_in_as(@user)

    patch identity_email_url, params: { email: "new_email@hey.com" }

    assert_response :unprocessable_entity
    assert_equal "john.smith@example.com", @user.reload.email
  end

  test "attempts are rate limited" do
    sign_in_as(@user)

    5.times { patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: "SecretWrong1*3" } }
    assert_response :unprocessable_entity

    patch identity_email_url, params: { email: "new_email@hey.com", password_challenge: FIXTURE_PASSWORD }

    assert_redirected_to edit_identity_email_url
    assert_equal "john.smith@example.com", @user.reload.email
  end
end
