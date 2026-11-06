require "test_helper"

module ActionAuth
  class UserTest < ActiveSupport::TestCase
    def setup
      @user = ActionAuth::User.new(email: "test@example.com", password: STRONG_PASSWORD)
    end

    test "should be valid" do
      assert @user.valid?
    end

    test "two simultaneous failures both count, and only one of them locks the account" do
      user = action_auth_users(:one)
      user.update_columns(failed_sign_in_attempts: 8)
      first = User.find(user.id)
      second = User.find(user.id)

      assert_not first.register_failed_sign_in
      assert second.register_failed_sign_in, "reached the limit, even though this copy was loaded with 8"

      assert_equal 10, user.reload.failed_sign_in_attempts
      assert user.account_locked?
    end

    test "only one of two simultaneous failures reports locking the account, so only one email goes out" do
      user = action_auth_users(:one)
      user.update_columns(failed_sign_in_attempts: 9)
      first = User.find(user.id)
      second = User.find(user.id)

      assert first.register_failed_sign_in
      assert_not second.register_failed_sign_in
    end

    test "a failure loaded just before someone else's lock doesn't clear that lock" do
      user = action_auth_users(:one)
      stale = User.find(user.id)
      user.update_columns(failed_sign_in_attempts: 10, account_locked_at: Time.current)

      stale.register_failed_sign_in

      assert user.reload.account_locked?
    end

    test "unlocking doesn't write when there's nothing to unlock" do
      user = action_auth_users(:one)

      assert_no_queries { user.unlock_account! }
    end

    test "the app's own columns and methods with common names aren't touched" do
      assert_empty User.column_names & %w[locked_at failed_attempts suspended_at]
      %i[locked? suspended? unlock! suspend! unsuspend!].each do |name|
        assert_not User.method_defined?(name), "#{name} would hide an app's own method or column"
      end
    end

    test "email should be present" do
      @user.email = "     "
      assert_not @user.valid?
    end

    test "password should be present" do
      user = User.new(email: "john.mcgee@example.com")
      assert_not user.valid?
    end

    test "email should be unique" do
      duplicate_user = @user.dup
      duplicate_user.email = @user.email.upcase
      @user.save
      assert_not duplicate_user.valid?
    end

    test "email should be saved as lowercase" do
      mixed_case_email = "Foo@ExAMPle.CoM"
      @user.email = mixed_case_email
      @user.save
      assert_equal mixed_case_email.downcase, @user.reload.email
    end

    test "email should be valid format" do
      valid_addresses = %w[user@example.com USER@foo.COM A_US-ER@foo.bar.org
                           first.last@foo.jp alice+bob@baz.cn]
      valid_addresses.each do |valid_address|
        @user.email = valid_address
        assert @user.valid?, "#{valid_address.inspect} should be valid"
      end
    end

    test "email should be invalid format" do
      invalid_addresses = %w[user@example,com user_at_foo.org user.name@example.
                             foo@bar_baz.com foo@bar+baz.com]
      invalid_addresses.each do |invalid_address|
        @user.email = invalid_address
        assert_not @user.valid?, "#{invalid_address.inspect} should be invalid"
      end
    end

    test "password should have a minimum length" do
      @user.password = @user.password_confirmation = "Aa1!" + "a" * 7
      assert_not @user.valid?
      assert_includes @user.errors[:password], "is too short (minimum is 12 characters)"
    end

    test "password should be saved as a digest" do
      @user.save
      assert_not_nil @user.password_digest
    end

    test "should generate email verification token" do
      @user.save
      token = @user.generate_token_for(:email_verification)
      assert_not_nil token
      subject = User.find_by_token_for(:email_verification, token)
      assert_equal @user, subject
    end

    test "should generate password reset token" do
      @user.save
      token = @user.generate_token_for(:password_reset)
      assert_not_nil token
      subject = User.find_by_token_for(:password_reset, token)
      assert_equal @user, subject
    end

    test "should verify email" do
      @user.toggle!(:verified)
      assert @user.verified?
    end

    test "should not verify email if email has not changed" do
      @user.save
      @user.update(email: "john.smith1@example.com")
      assert_not @user.verified?
    end

    test "should delete sessions after password change" do
      @user.save
      session = @user.sessions.create
      @user.update!(password: "An0ther$ecurePassw0rd!")
      assert_not Session.exists?(session.id)
    end

    test "keeps the current session when the password changes" do
      @user.save!
      current = @user.sessions.create!
      other = @user.sessions.create!
      Current.session = current

      @user.update!(password: "An0ther$ecurePassw0rd!")

      assert Session.exists?(current.id)
      assert_not Session.exists?(other.id)
    end

    {
      "password123!" => "missing an uppercase letter",
      "PASSWORD123!" => "missing a lowercase letter",
      "PasswordABCD!" => "missing a number",
      "Password1234" => "missing a special character"
    }.each do |password, problem|
      test "rejects a password #{problem}" do
        @user.password = password

        assert_not @user.valid?
        assert_match "must include at least one uppercase letter", @user.errors[:password].join
      end

      test "allows a password #{problem} when complexity checks are off" do
        with_action_auth_config(password_complexity_check: false) do
          @user.password = password

          assert @user.valid?, @user.errors.full_messages.to_sentence
        end
      end
    end

    test "existing records are saved without re-checking the password" do
      user = action_auth_users(:one)

      assert user.update(verified: true), user.errors.full_messages.to_sentence
    end

    test "phone numbers are normalized and must be international" do
      @user.phone_number = "+1 (555) 000-1111"
      assert @user.valid?
      assert_equal "+15550001111", @user.phone_number

      @user.phone_number = "5550001111"
      assert_not @user.valid?
    end

    test "phone numbers are unique" do
      action_auth_users(:one).update!(phone_number: "+15550001111")
      @user.phone_number = "+15550001111"

      assert_not @user.valid?
    end

    test "second_factor_enabled? reflects registered keys" do
      user = action_auth_users(:one)
      assert_not user.second_factor_enabled?

      user.webauthn_credentials.create!(external_id: "abc", public_key: "key", nickname: "Key", sign_count: 0)
      assert user.reload.second_factor_enabled?
    end

    test "second_factor_enabled? is false when WebAuthn is turned off" do
      user = action_auth_users(:one)
      user.webauthn_credentials.create!(external_id: "abc", public_key: "key", nickname: "Key", sign_count: 0)

      with_action_auth_config(webauthn_enabled: false) do
        assert_not user.second_factor_enabled?
      end
    end

    test "magic tokens and password reset tokens expire and die with the password" do
      user = action_auth_users(:one)
      magic = user.generate_token_for(:magic_token)
      reset = user.generate_token_for(:password_reset)
      assert_equal user, User.find_by_token_for(:magic_token, magic)
      assert_equal user, User.find_by_token_for(:password_reset, reset)

      travel 21.minutes do
        assert_nil User.find_by_token_for(:magic_token, magic)
        assert_nil User.find_by_token_for(:password_reset, reset)
      end

      user.update!(password: STRONG_PASSWORD)
      assert_nil User.find_by_token_for(:magic_token, magic)
      assert_nil User.find_by_token_for(:password_reset, reset)
    end

    test "claiming a magic link uses it up and verifies the email" do
      user = action_auth_users(:one)
      user.update!(verified: false)
      token = user.generate_token_for(:magic_token)

      assert user.claim_magic_link

      assert user.verified
      assert_not_nil user.magic_link_used_at
      assert_nil User.find_by_token_for(:magic_token, token)
    end

    test "only one of two simultaneous clicks claims a magic link" do
      token = action_auth_users(:one).generate_token_for(:magic_token)
      first_click = User.find_by_token_for(:magic_token, token)
      second_click = User.find_by_token_for(:magic_token, token)

      assert first_click.claim_magic_link
      assert_not second_click.claim_magic_link
    end

    test "only one of two simultaneous clicks claims a later magic link either" do
      action_auth_users(:one).claim_magic_link
      travel 1.minute

      token = action_auth_users(:one).reload.generate_token_for(:magic_token)
      first_click = User.find_by_token_for(:magic_token, token)
      second_click = User.find_by_token_for(:magic_token, token)

      assert first_click.claim_magic_link
      assert_not second_click.claim_magic_link
    end

    test "claiming a magic link leaves other accounts alone" do
      other = action_auth_users(:two)
      token = other.generate_token_for(:magic_token)

      action_auth_users(:one).claim_magic_link

      assert_equal other, User.find_by_token_for(:magic_token, token)
    end

    test "a claim doesn't need the account to pass validation" do
      user = action_auth_users(:one)
      user.update_column(:email, "not an email address")

      assert user.reload.claim_magic_link
    end

    test "the click that loses doesn't replace the password a second time" do
      user = action_auth_users(:one)
      token = user.generate_token_for(:magic_token)
      first_click = User.find_by_token_for(:magic_token, token)
      second_click = User.find_by_token_for(:magic_token, token)
      assert first_click.claim_magic_link
      digest = user.reload.password_digest

      assert_not second_click.claim_magic_link

      assert_equal digest, user.reload.password_digest
    end

    test "a claim that can't finish leaves everything as it was, so that trying again still replaces the password" do
      user = action_auth_users(:one)
      other_device = user.sessions.create!

      stub_class_method(ConnectedAccount, :table_exists?, -> { raise "the database went away" }) do
        assert_raises(RuntimeError) { user.claim_magic_link }
      end

      user.reload
      assert_not user.verified
      assert_nil user.magic_link_used_at
      assert user.authenticate_password(FIXTURE_PASSWORD)
      assert user.sessions.exists?(other_device.id)
    end

    test "a claim doesn't need the connected accounts table yet" do
      user = action_auth_users(:one)

      stub_class_method(ConnectedAccount, :table_exists?, false) do
        assert user.claim_magic_link
      end

      assert_not user.authenticate_password(FIXTURE_PASSWORD)
    end

    test "an empty verified column counts as unverified" do
      user = action_auth_users(:one)
      user.update_column(:verified, nil)

      assert user.reload.claim_magic_link

      assert user.verified
      assert_not user.authenticate_password(FIXTURE_PASSWORD)
    end

    test "a claim is refused if the account stopped being verified after it was loaded" do
      user = action_auth_users(:one)
      user.update!(verified: true)
      loaded_earlier = User.find(user.id)
      user.update!(email: "new_address@example.com")

      assert_not loaded_earlier.claim_magic_link

      assert_not user.reload.verified
      assert user.authenticate_password(FIXTURE_PASSWORD)
    end

    test "verifying needs the right password" do
      user = action_auth_users(:one)

      assert_not user.verify_email_with_password("not the password")
      assert_not user.reload.verified

      assert user.verify_email_with_password(FIXTURE_PASSWORD)
      assert user.reload.verified
    end

    test "verifying is refused during a lock" do
      user = action_auth_users(:one)
      user.update!(account_locked_at: Time.current)

      assert_not user.verify_email_with_password(FIXTURE_PASSWORD)
      assert_not user.reload.verified
    end

    test "verifying is refused if the email changed after the link was checked" do
      user = action_auth_users(:one)
      loaded_earlier = User.find(user.id)
      user.update!(email: "new_address@example.com")

      assert_not loaded_earlier.verify_email_with_password(FIXTURE_PASSWORD)

      assert_not user.reload.verified
    end

    test "a reset is refused if the email changed after the link was checked" do
      user = action_auth_users(:one)
      loaded_earlier = User.find(user.id)
      user.update!(email: "new_address@example.com")

      assert_not loaded_earlier.reset_password_from_emailed_link(password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD)

      user.reload
      assert_not user.verified
      assert user.authenticate_password(FIXTURE_PASSWORD)
    end

    test "changing the email marks it unverified even if this copy already thought it was" do
      user = action_auth_users(:one)
      loaded_earlier = User.find(user.id)
      user.update!(verified: true)

      loaded_earlier.update!(email: "new_address@example.com")

      assert_not user.reload.verified
    end

    test "a reset that can't finish leaves everything as it was" do
      user = action_auth_users(:one)
      other_device = user.sessions.create!

      stub_class_method(ConnectedAccount, :table_exists?, -> { raise "the database went away" }) do
        assert_raises(RuntimeError) do
          user.reset_password_from_emailed_link(password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD)
        end
      end

      user.reload
      assert_not user.verified
      assert user.authenticate_password(FIXTURE_PASSWORD)
      assert user.sessions.exists?(other_device.id)
    end

    test "a reset doesn't need the connected accounts table yet" do
      user = action_auth_users(:one)

      stub_class_method(ConnectedAccount, :table_exists?, false) do
        assert user.reset_password_from_emailed_link(password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD)
      end

      assert user.reload.verified
    end

    test "the password only counts as usable when it could be known" do
      assert action_auth_users(:one).password_usable?

      assert_not User.new(email: "abc#{User::SMS_EMAIL_SUFFIX}").password_usable?
    end
  end
end
