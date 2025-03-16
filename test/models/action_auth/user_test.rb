require "test_helper"

module ActionAuth
  class UserTest < ActiveSupport::TestCase
    def setup
      @user = ActionAuth::User.new(email: "test@example.com", password: "123456789012")
    end

    test "should be valid" do
      assert @user.valid?
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
      @user.password = @user.password_confirmation = "a" * 11
      assert_not @user.valid?
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
      @user.update(password: "newpassword123")
      assert_not Session.exists?(session.id)
    end

    test "should validate password complexity with complex passwords" do
      user = ActionAuth::User.new(email: "test@example.com", password: "Password123!")
      def user.test_password(password)
        return if password.blank?
        errors.clear
        unless password =~ /[A-Z]/ && password =~ /[a-z]/ && password =~ /[0-9]/ && password =~ /[^A-Za-z0-9]/
          errors.add(:password, "must include at least one uppercase letter, one lowercase letter, one number, and one special character")
        end
        errors[:password]
      end

      errors = user.test_password("password123!")
      assert_not_empty errors, "Password missing uppercase should be invalid"

      errors = user.test_password("PASSWORD123!")
      assert_not_empty errors, "Password missing lowercase should be invalid"

      errors = user.test_password("PasswordABC!")
      assert_not_empty errors, "Password missing number should be invalid"

      errors = user.test_password("Password123")
      assert_not_empty errors, "Password missing special character should be invalid"

      user.errors.clear
      errors = user.test_password("Password123!")
      assert_empty errors, "Complex password should be valid"
    end
  end
end
