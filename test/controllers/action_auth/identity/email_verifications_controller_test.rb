require "test_helper"

class ActionAuth::Identity::EmailVerificationsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  INCORRECT = "That password is incorrect".freeze

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: false)
  end

  def verify(password: FIXTURE_PASSWORD, sid: @user.generate_token_for(:email_verification))
    patch identity_email_verification_url, params: { sid: sid, password: password }
  end

  def assert_link_refused(sid)
    get identity_email_verification_url(sid: sid)
    assert_redirected_to edit_identity_email_url
    assert_equal "That email verification link is invalid", flash[:alert]

    verify(sid: sid)
    assert_redirected_to edit_identity_email_url
    assert_equal "That email verification link is invalid", flash[:alert]

    assert_not @user.reload.verified
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

  test "opening a link only asks for the password, however many times it's opened" do
    sid = @user.generate_token_for(:email_verification)

    3.times { get identity_email_verification_url(sid: sid) }

    assert_response :success
    assert_select "strong", @user.email
    assert_select "form[action=?][method=post]", identity_email_verification_path do
      assert_select "input[name=_method][value=patch]"
      assert_select "input[name=sid][value=?]", sid
      assert_select "input[type=password][name=password][autocomplete=current-password]"
    end
    assert_select "a[href=?]", new_identity_password_reset_path
    assert_not @user.reload.verified
  end

  test "the link and the password together verify the email" do
    verify

    assert_response :see_other
    assert_redirected_to sign_in_url
    assert_equal "Thank you for verifying your email address", flash[:notice]
    assert @user.reload.verified
    assert @user.authenticate_password(FIXTURE_PASSWORD)
  end

  test "verifying leaves the account's sessions and connected accounts alone" do
    other_device = @user.sessions.create!
    connected_account = @user.connected_accounts.create!(provider: "developer", uid: "12345")

    verify

    assert @user.sessions.exists?(other_device.id)
    assert @user.connected_accounts.exists?(connected_account.id)
  end

  test "the wrong password doesn't verify" do
    verify(password: "not the password")

    assert_response :unprocessable_entity
    assert_select "[role=alert]", INCORRECT
    assert_select "input[name=sid]"
    assert_not @user.reload.verified
  end

  test "a missing or non-string password doesn't verify, and isn't counted as a guess" do
    sid = @user.generate_token_for(:email_verification)

    [{}, { password: "" }, { password: ["x"] }, { password: { a: "b" } }].each do |params|
      Rails.cache.clear
      patch identity_email_verification_url, params: params.merge(sid: sid)

      assert_response :unprocessable_entity
    end

    assert_not @user.reload.verified
    assert_equal 0, @user.failed_sign_in_attempts
  end

  test "wrong passwords count towards locking the account, so this can't be used to keep guessing" do
    with_action_auth_config(account_lockout_max_attempts: 2) do
      2.times { verify(password: "not the password") }
    end

    assert @user.reload.account_locked?
    assert_enqueued_emails 1
  end

  test "a locked account gets the same answer, even with the right password" do
    @user.update!(account_locked_at: Time.current, failed_sign_in_attempts: 10)

    verify

    assert_response :unprocessable_entity
    assert_select "[role=alert]", INCORRECT
    assert_not @user.reload.verified
  end

  test "attempts are rate limited" do
    5.times { verify(password: "not the password") }

    verify

    assert_response :see_other
    assert_redirected_to sign_in_url
    assert_equal "Too many attempts. Try again later.", flash[:alert]
    assert_not @user.reload.verified
  end

  test "an account that's already verified isn't asked for anything" do
    @user.update!(verified: true)

    get identity_email_verification_url(sid: @user.generate_token_for(:email_verification))

    assert_redirected_to sign_in_url
    assert_equal "Your email address is already verified", flash[:notice]
  end

  test "the Verify Email link goes to the form without reporting an error" do
    get identity_email_verification_url

    assert_redirected_to edit_identity_email_url
    assert_nil flash[:alert]
  end

  test "submitting with no link goes to that form too" do
    patch identity_email_verification_url, params: { password: FIXTURE_PASSWORD }

    assert_redirected_to edit_identity_email_url
    assert_not @user.reload.verified
  end

  test "an expired link does not verify" do
    sid = @user.generate_token_for(:email_verification)

    travel 3.days

    assert_link_refused(sid)
  end

  test "a link for an old address does not verify the new one" do
    sid = @user.generate_token_for(:email_verification)
    @user.update!(email: "changed@example.com")

    assert_link_refused(sid)
  end

  test "a garbage link does not verify" do
    assert_link_refused("garbage")
  end
end
