require "test_helper"

module ActionAuth
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    def sign_up(email: "new@example.com", password: STRONG_PASSWORD, confirmation: password)
      post sign_up_path, params: { email: email, password: password, password_confirmation: confirmation }
    end

    test "should get new" do
      get sign_up_path
      assert_response :success
    end

    test "signs up and asks for the email to be verified" do
      assert_difference("User.count") { sign_up }

      assert_redirected_to sign_in_path
      assert_match "Please check your email", flash[:notice]
      assert_enqueued_emails 1
      assert_not User.find_by(email: "new@example.com").verified
      assert_signed_out
    end

    test "signs straight in when verification is turned off" do
      with_action_auth_config(verify_email_on_sign_in: false) do
        assert_difference("Session.count") { sign_up }

        assert_redirected_to "/"
        assert_enqueued_emails 0
        assert_signed_in
      end
    end

    test "sends people to the configured path when verification is turned off" do
      with_action_auth_config(verify_email_on_sign_in: false, after_sign_in_path: "/welcome") do
        sign_up
      end

      assert_redirected_to "/welcome"
    end

    test "the password confirmation has to match" do
      assert_no_difference("User.count") { sign_up(confirmation: "Different#{STRONG_PASSWORD}") }

      assert_response :unprocessable_entity
    end

    test "a short password is rejected" do
      assert_no_difference("User.count") { sign_up(password: "Ab1!") }

      assert_response :unprocessable_entity
      assert_select "li", /too short/
    end

    test "a password without enough variety is rejected" do
      assert_no_difference("User.count") { sign_up(password: "alllowercaseletters") }

      assert_response :unprocessable_entity
      assert_select "li", /must include at least one uppercase letter/
    end

    test "password complexity can be turned off" do
      with_action_auth_config(password_complexity_check: false) do
        assert_difference("User.count") { sign_up(password: "alllowercaseletters") }
      end
    end

    test "a pwned password is rejected and the email is kept in the form" do
      with_pwned_count(5) do
        assert_no_difference("User.count") { sign_up }
      end

      assert_response :unprocessable_entity
      assert_select "li", /has been pwned 5 times/
      assert_select "input[name=email][value=?]", "new@example.com"
    end

    test "sign up still works when Have I Been Pwned is down" do
      with_pwned_outage do
        assert_difference("User.count") { sign_up }
      end
    end

    test "pwned checks can be turned off" do
      with_action_auth_config(pwned_enabled: false) do
        with_pwned_count(5) do
          assert_difference("User.count") { sign_up }
        end
      end
    end

    test "a missing or non-string password is an error, not a crash" do
      [{ email: "a@example.com" }, { email: "a@example.com", password: ["x"] }, { email: "a@example.com", password: { a: "b" } }].each do |params|
        Rails.cache.clear

        assert_no_difference("User.count", "for #{params.inspect}") { post sign_up_path, params: params }

        assert_response :unprocessable_entity
        assert_select "li", /Password can't be blank/
      end
    end

    test "an email that's taken is rejected" do
      assert_no_difference("User.count") { sign_up(email: action_auth_users(:one).email) }

      assert_response :unprocessable_entity
      assert_select "li", /Email has already been taken/
    end

    test "attempts are rate limited and the message is visible" do
      3.times { sign_up(confirmation: "nope") }
      assert_response :unprocessable_entity

      assert_no_difference("User.count") { sign_up }

      assert_redirected_to sign_up_path
      follow_redirect!
      assert_select "[role=alert]", "Too many registration attempts. Try again later."
    end
  end
end
