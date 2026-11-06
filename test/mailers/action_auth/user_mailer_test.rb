require "test_helper"

module ActionAuth
  class UserMailerTest < ActionMailer::TestCase
    setup do
      @user = action_auth_users(:one)
    end

    test "password_reset links to a working token in both formats" do
      mail = ActionAuth::UserMailer.with(user: @user).password_reset

      assert_equal "Reset your password", mail.subject
      assert_equal [@user.email], mail.to
      assert_equal 2, mail.parts.size
      mail.parts.each do |part|
        token = part.body.to_s[/sid=([^"\s]+)/, 1]
        assert_equal @user, User.find_by_token_for(:password_reset, CGI.unescape(token))
      end
    end

    test "account_locked says how long for and how to get back in, in both formats" do
      mail = ActionAuth::UserMailer.with(user: @user).account_locked

      assert_equal "Your account has been locked", mail.subject
      assert_equal [@user.email], mail.to
      assert_equal 2, mail.parts.size
      mail.parts.each do |part|
        assert_match "30 minutes", part.body.to_s
        assert_match "/identity/password_reset/new", part.body.to_s
      end
      assert_no_match(/<\w+>/, mail.text_part.body.to_s)
    end

    test "account_locked doesn't promise an end to a lock that has none" do
      with_action_auth_config(account_lockout_duration: nil) do
        mail = ActionAuth::UserMailer.with(user: @user).account_locked

        assert_no_match(/for the next/, mail.text_part.body.to_s)
        assert_no_match(/for the next/, mail.html_part.body.to_s)
      end
    end

    test "the text version of the reset email has no HTML in it" do
      mail = ActionAuth::UserMailer.with(user: @user).password_reset

      assert_no_match(/<\w+>/, mail.text_part.body.to_s)
    end

    test "email_verification links to a working token in both formats" do
      mail = ActionAuth::UserMailer.with(user: @user).email_verification

      assert_equal "Verify your email", mail.subject
      assert_equal [@user.email], mail.to
      assert_equal 2, mail.parts.size
      mail.parts.each do |part|
        token = part.body.to_s[/sid=([^"\s]+)/, 1]
        assert_equal @user, User.find_by_token_for(:email_verification, CGI.unescape(token))
        assert_match "You'll be asked for your password", CGI.unescapeHTML(part.body.to_s)
        assert_match "If you didn't sign up", CGI.unescapeHTML(part.body.to_s)
      end
    end

    test "magic_link links to a working token in both formats" do
      mail = ActionAuth::UserMailer.with(user: @user).magic_link

      assert_equal "Sign in to your account", mail.subject
      assert_equal [@user.email], mail.to
      assert_equal 2, mail.parts.size
      mail.parts.each do |part|
        token = part.body.to_s[/token=([^"\s]+)/, 1]
        assert_equal @user, User.find_by_token_for(:magic_token, CGI.unescape(token))
      end
    end

    test "comes from the configured address, read when the mail is built" do
      with_action_auth_config(default_from_email: "auth@example.org") do
        assert_equal ["auth@example.org"], ActionAuth::UserMailer.with(user: @user).magic_link.from
      end
    end
  end
end
