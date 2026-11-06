require "test_helper"

class AccountLockoutTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  INCORRECT = "That email or password is incorrect".freeze

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: true)
  end

  def attempt_sign_in(password, email: @user.email)
    # The rate limit is a separate defense, and is tested on its own.
    Rails.cache.clear
    post action_auth.sign_in_path, params: { email: email, password: password }
  end

  def fail_sign_in(times = 1)
    times.times { attempt_sign_in("not the password") }
  end

  def lock_account
    fail_sign_in(ActionAuth.configuration.account_lockout_max_attempts)
    assert @user.reload.account_locked?
  end

  test "is on by default" do
    assert ActionAuth::Configuration.new.account_lockout_enabled?
    assert_equal 10, ActionAuth::Configuration.new.account_lockout_max_attempts
    assert_equal 30.minutes, ActionAuth::Configuration.new.account_lockout_duration
  end

  test "failures below the limit don't lock the account" do
    fail_sign_in(9)

    assert_equal 9, @user.reload.failed_sign_in_attempts
    assert_not @user.account_locked?

    attempt_sign_in(FIXTURE_PASSWORD)

    assert_signed_in
  end

  test "the limit locks the account and the right password no longer works" do
    lock_account

    assert_no_difference -> { @user.sessions.count } do
      attempt_sign_in(FIXTURE_PASSWORD)
    end

    assert_signed_out
  end

  test "a locked account answers the same whether the password is right or wrong, so guessing can't continue" do
    lock_account

    attempt_sign_in("not the password")
    wrong = [response.status, response.location, flash[:alert]]

    attempt_sign_in(FIXTURE_PASSWORD)

    assert_equal wrong, [response.status, response.location, flash[:alert]]
    assert_equal INCORRECT, flash[:alert]
  end

  test "a locked account looks the same as a wrong password or an unknown email, so it doesn't reveal who has an account" do
    fail_sign_in
    assert_equal INCORRECT, flash[:alert]

    attempt_sign_in("not the password", email: "nobody@example.com")
    assert_equal INCORRECT, flash[:alert]

    lock_account
    attempt_sign_in(FIXTURE_PASSWORD)
    assert_equal INCORRECT, flash[:alert]
  end

  test "an unknown email doesn't raise or create anything" do
    assert_no_difference "ActionAuth::User.count" do
      attempt_sign_in("not the password", email: "nobody@example.com")
    end

    assert_redirected_to action_auth.sign_in_path(email_hint: "nobody@example.com")
  end

  test "the account's owner is told by email, once" do
    assert_enqueued_emails 1 do
      lock_account
      fail_sign_in(5)
      attempt_sign_in(FIXTURE_PASSWORD)
    end
  end

  test "attempts during a lock don't extend it" do
    freeze_time
    lock_account
    locked_at = @user.account_locked_at

    travel 29.minutes
    fail_sign_in(5)

    assert_equal locked_at, @user.reload.account_locked_at
    assert_equal 10, @user.failed_sign_in_attempts

    travel 2.minutes
    attempt_sign_in(FIXTURE_PASSWORD)

    assert_signed_in
  end

  test "a lock ends by itself" do
    lock_account

    travel 31.minutes
    attempt_sign_in(FIXTURE_PASSWORD)

    assert_signed_in
    assert_equal 0, @user.reload.failed_sign_in_attempts
    assert_nil @user.account_locked_at
  end

  test "the next failure after a lock ends starts the count again" do
    lock_account

    travel 31.minutes
    fail_sign_in

    @user.reload
    assert_equal 1, @user.failed_sign_in_attempts
    assert_nil @user.account_locked_at

    attempt_sign_in(FIXTURE_PASSWORD)

    assert_signed_in
  end

  test "a lock with no duration lasts until it's lifted" do
    with_action_auth_config(account_lockout_duration: nil) do
      lock_account

      travel 1.year
      assert @user.reload.account_locked?
      fail_sign_in

      assert @user.reload.account_locked?, "a failure shouldn't have cleared it"

      attempt_sign_in(FIXTURE_PASSWORD)
      assert_signed_out

      @user.unlock_account!
      attempt_sign_in(FIXTURE_PASSWORD)
      assert_signed_in
    end
  end

  test "signing in resets the count" do
    fail_sign_in(9)
    attempt_sign_in(FIXTURE_PASSWORD)

    assert_equal 0, @user.reload.failed_sign_in_attempts

    fail_sign_in(9)
    assert_not @user.reload.account_locked?
  end

  test "an empty form isn't counted" do
    attempt_sign_in("")

    assert_equal 0, @user.reload.failed_sign_in_attempts
  end

  test "the limit can be changed" do
    with_action_auth_config(account_lockout_max_attempts: 3) do
      fail_sign_in(3)

      assert @user.reload.account_locked?
    end
  end

  test "it can be turned off" do
    with_action_auth_config(account_lockout_enabled: false) do
      assert_no_enqueued_emails do
        fail_sign_in(25)
      end

      assert_equal 0, @user.reload.failed_sign_in_attempts
      attempt_sign_in(FIXTURE_PASSWORD)
      assert_signed_in
    end
  end

  test "being signed in elsewhere isn't affected, so that nobody can be kicked out by guessing" do
    sign_in_as(@user)
    assert_signed_in

    fail_sign_in(10)

    assert @user.reload.account_locked?
    assert_signed_in
  end

  test "a password reset lifts the lock" do
    lock_account
    token = @user.generate_token_for(:password_reset)

    patch action_auth.identity_password_reset_path,
      params: { sid: token, password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }

    assert_not @user.reload.account_locked?
    assert_equal 0, @user.failed_sign_in_attempts

    attempt_sign_in(STRONG_PASSWORD)
    assert_signed_in
  end

  test "changing the password lifts the lock" do
    sign_in_as(@user)
    lock_account

    patch action_auth.password_path, params: {
      password_challenge: FIXTURE_PASSWORD, password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD
    }

    assert_not @user.reload.account_locked?
  end

  test "a magic link still works, and lifts the lock" do
    lock_account

    post action_auth.magics_sign_ins_path, params: { token: @user.generate_token_for(:magic_token) }

    assert_signed_in
    assert_not @user.reload.account_locked?
  end

  test "a passkey still works, and lifts the lock" do
    user, client = create_user_with_authenticator(email: "passkey@example.com")
    @user = user
    lock_account

    get action_auth.new_sessions_passkey_path
    post_webauthn action_auth.sessions_passkeys_path, client.get(challenge: webauthn_options_on_page["challenge"], user_verified: true)

    assert_response :success
    assert_signed_in
    assert_not user.reload.account_locked?
  end

  test "a password that's right while locked doesn't start the second factor" do
    user, = create_user_with_authenticator(email: "passkey@example.com")
    @user = user
    lock_account

    attempt_sign_in(STRONG_PASSWORD)

    assert_redirected_to action_auth.sign_in_path(email_hint: user.email)
    get action_auth.new_webauthn_credential_authentications_path
    assert_redirected_to action_auth.sign_in_path
  end

  test "an account with a placeholder address isn't sent the email" do
    @user.update!(email: "#{SecureRandom.hex(32)}#{ActionAuth::User::SMS_EMAIL_SUFFIX}")

    assert_no_enqueued_emails do
      lock_account
    end
  end

  test "failing to send the email doesn't break the sign in form" do
    raise_on_deliver = -> { raise Errno::ECONNREFUSED }

    ActionMailer::Parameterized::MessageDelivery.stub_any_instance(:deliver_later, raise_on_deliver) do
      lock_account
    end

    assert_redirected_to action_auth.sign_in_path(email_hint: @user.email)
    assert_equal INCORRECT, flash[:alert]
  end

  class SmsCodes < ActionDispatch::IntegrationTest
    setup do
      @user = action_auth_users(:one)
      @user.update!(phone_number: "+11234567890")
    end

    def request_code
      Rails.cache.clear
      post action_auth.sms_auths_requests_path, params: { phone_number: @user.phone_number }
      @user.reload.sms_code
    end

    def guess(code)
      Rails.cache.clear
      post action_auth.sms_auths_sign_ins_path, params: { sms_code: code }
    end

    test "wrong codes count towards the lock, which holds even without a working cache" do
      code = request_code
      wrong = code == "111111" ? "222222" : "111111"

      10.times { guess(wrong) }

      assert @user.reload.account_locked?

      assert_no_difference -> { @user.sessions.count } do
        guess(code)
      end

      assert_equal "Too many attempts. Try again later.", flash[:alert]
    end

    test "while locked the answer is the same for a right and a wrong code" do
      code = request_code
      @user.update!(account_locked_at: Time.current)

      guess(code)
      right = [response.location, flash[:alert]]
      guess("000000")

      assert_equal right, [response.location, flash[:alert]]
    end

    test "a locked account isn't sent a code, and the form doesn't say why" do
      @user.update!(account_locked_at: Time.current)

      assert_no_changes -> { @user.reload.sms_code } do
        stub_class_method(SmsSender, :send_code, ->(*) { flunk "shouldn't send a code" }) do
          post action_auth.sms_auths_requests_path, params: { phone_number: @user.phone_number }
        end
      end

      assert_redirected_to action_auth.sms_auths_sign_ins_path
      assert_equal "Check your phone for a SMS Code.", flash[:notice]
    end

    test "the right code resets the count" do
      code = request_code
      guess(code == "111111" ? "222222" : "111111")
      assert_equal 1, @user.reload.failed_sign_in_attempts

      guess(code)

      assert_signed_in
      assert_equal 0, @user.reload.failed_sign_in_attempts
    end

    test "submitting no code isn't counted" do
      request_code
      guess("")

      assert_equal 0, @user.reload.failed_sign_in_attempts
    end

    test "no phone number cookie doesn't match an account" do
      guess("123456")

      assert_redirected_to action_auth.sign_in_path
      assert_equal 0, @user.reload.failed_sign_in_attempts
    end
  end
end
