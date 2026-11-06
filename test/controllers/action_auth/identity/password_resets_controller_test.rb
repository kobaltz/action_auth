require "test_helper"

class ActionAuth::Identity::PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  GENERIC_RESPONSE = "If there's an account with that email address, you'll receive reset instructions shortly."

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: true)
  end

  def reset_password(password: STRONG_PASSWORD, sid: @user.generate_token_for(:password_reset), confirmation: password)
    patch identity_password_reset_url, params: { sid: sid, password: password, password_confirmation: confirmation }
  end

  test "should get new" do
    get new_identity_password_reset_url
    assert_response :success
  end

  test "should get edit" do
    get edit_identity_password_reset_url(sid: @user.generate_token_for(:password_reset))
    assert_response :success
  end

  test "edit with a bad token goes back to the request form" do
    get edit_identity_password_reset_url(sid: "garbage")

    assert_redirected_to new_identity_password_reset_url
    assert_equal "That password reset link is invalid", flash[:alert]
  end

  test "a verified address gets the email" do
    post identity_password_reset_url, params: { email: @user.email }

    assert_enqueued_emails 1
    assert_redirected_to sign_in_url
    assert_equal GENERIC_RESPONSE, flash[:notice]
  end

  test "an unverified address gets the same response and the email, since finishing a reset proves the address" do
    @user.update!(verified: false)

    post identity_password_reset_url, params: { email: @user.email }

    assert_enqueued_emails 1
    assert_redirected_to sign_in_url
    assert_equal GENERIC_RESPONSE, flash[:notice]
  end

  test "an unknown address gets the same response and no email" do
    post identity_password_reset_url, params: { email: "invalid_email@hey.com" }

    assert_enqueued_emails 0
    assert_redirected_to sign_in_url
    assert_equal GENERIC_RESPONSE, flash[:notice]
  end

  test "a missing or non-string email sends nothing" do
    [{}, { email: ["a@b.co"] }, { email: { a: "b" } }].each do |params|
      Rails.cache.clear
      post identity_password_reset_url, params: params

      assert_redirected_to sign_in_url
    end
    assert_enqueued_emails 0
  end

  test "requests are rate limited" do
    5.times { post identity_password_reset_url, params: { email: @user.email } }

    post identity_password_reset_url, params: { email: @user.email }

    assert_enqueued_emails 5
    assert_redirected_to new_identity_password_reset_url
    assert_equal "Too many requests. Try again later.", flash[:alert]
  end

  test "should update password" do
    reset_password

    assert_redirected_to sign_in_url
    assert_equal "Your password was reset successfully. Please sign in", flash[:notice]
    assert User.authenticate_by(email: @user.email, password: STRONG_PASSWORD)
  end

  test "resetting the password signs out every device" do
    session = @user.sessions.create!

    reset_password

    assert_not ActionAuth::Session.exists?(session.id)
  end

  test "a verified account keeps its connected accounts" do
    connected_account = @user.connected_accounts.create!(provider: "developer", uid: "12345")

    reset_password

    assert @user.connected_accounts.exists?(connected_account.id)
  end

  test "finishing a reset on an unverified account verifies it and removes everything from before" do
    @user.update!(verified: false)
    session = @user.sessions.create!
    connected_account = @user.connected_accounts.create!(provider: "developer", uid: "12345")

    reset_password

    assert_redirected_to sign_in_url
    assert @user.reload.verified
    assert_not ActionAuth::Session.exists?(session.id)
    assert_not ActionAuth::ConnectedAccount.exists?(connected_account.id)
    assert User.authenticate_by(email: @user.email, password: STRONG_PASSWORD)
  end

  test "a reset that's rejected on an unverified account changes nothing" do
    @user.update!(verified: false)
    session = @user.sessions.create!
    connected_account = @user.connected_accounts.create!(provider: "developer", uid: "12345")

    reset_password(password: "alllowercaseletters")

    assert_response :unprocessable_entity
    assert_select "p", /will also verify it/
    assert_not @user.reload.verified
    assert ActionAuth::Session.exists?(session.id)
    assert ActionAuth::ConnectedAccount.exists?(connected_account.id)
  end

  test "the form says what a reset will also do to an unverified account" do
    @user.update!(verified: false)

    get edit_identity_password_reset_url(sid: @user.generate_token_for(:password_reset))

    assert_select "p", /will also verify it/
  end

  test "the form doesn't say that to a verified account" do
    get edit_identity_password_reset_url(sid: @user.generate_token_for(:password_reset))

    assert_select "p", text: /will also verify it/, count: 0
  end

  test "a link sent to an old address stops working when the email changes" do
    sid = @user.generate_token_for(:password_reset)
    @user.update!(email: "changed@example.com")

    reset_password(sid: sid)

    assert_redirected_to new_identity_password_reset_url
    assert_equal "That password reset link is invalid", flash[:alert]
    assert_not @user.reload.verified
    assert @user.authenticate_password(FIXTURE_PASSWORD)
  end

  test "a reset link only works once" do
    sid = @user.generate_token_for(:password_reset)
    reset_password(sid: sid)

    reset_password(sid: sid, password: "An0ther$ecurePassw0rd!")

    assert_redirected_to new_identity_password_reset_url
    assert_not User.authenticate_by(email: @user.email, password: "An0ther$ecurePassw0rd!")
  end

  test "should not update password with expired token" do
    sid = @user.generate_token_for(:password_reset)

    travel 30.minutes

    reset_password(sid: sid)

    assert_redirected_to new_identity_password_reset_url
    assert_equal "That password reset link is invalid", flash[:alert]
  end

  test "a blank password is an error whether or not pwned checks are on" do
    [true, false].each do |pwned_enabled|
      with_action_auth_config(pwned_enabled: pwned_enabled) do
        reset_password(password: "")

        assert_response :unprocessable_entity
        assert_select "li", /Password can't be blank/
      end
    end
  end

  test "a missing password is an error" do
    patch identity_password_reset_url, params: { sid: @user.generate_token_for(:password_reset) }

    assert_response :unprocessable_entity
  end

  test "a weak password is rejected" do
    reset_password(password: "alllowercaseletters")

    assert_response :unprocessable_entity
    assert_select "li", /must include at least one uppercase letter/
  end

  test "a pwned password is rejected" do
    with_pwned_count(42) { reset_password }

    assert_response :unprocessable_entity
    assert_select "li", /has been pwned 42 times/
  end

  test "the reset still works when Have I Been Pwned is down" do
    with_pwned_outage(Pwned::TimeoutError.new("timed out")) { reset_password }

    assert_redirected_to sign_in_url
  end
end
