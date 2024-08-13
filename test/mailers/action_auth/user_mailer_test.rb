require "test_helper"

module ActionAuth
  class UserMailerTest < ActionMailer::TestCase
    setup do
      @user = action_auth_users(:one)
    end

    test "password_reset" do
      mail = ActionAuth::UserMailer.with(user: @user).password_reset
      assert_equal "Reset your password", mail.subject
      assert_equal [@user.email], mail.to
    end

    test "email_verification" do
      mail = ActionAuth::UserMailer.with(user: @user).email_verification
      assert_equal "Verify your email", mail.subject
      assert_equal [@user.email], mail.to
    end

    test "magic_link" do
      mail = ActionAuth::UserMailer.with(user: @user).magic_link
      assert_equal "Sign in to your account", mail.subject
      assert_equal [@user.email], mail.to
    end
  end
end
