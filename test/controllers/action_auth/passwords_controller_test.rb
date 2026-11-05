require "test_helper"

module ActionAuth
  class PasswordsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
    end

    def change_password(password: STRONG_PASSWORD, challenge: FIXTURE_PASSWORD, confirmation: password)
      patch password_path, params: { password_challenge: challenge, password: password, password_confirmation: confirmation }
    end

    test "edit requires sign in" do
      get edit_password_path
      assert_redirected_to sign_in_path
    end

    test "update requires sign in" do
      patch password_path, params: { password: STRONG_PASSWORD }
      assert_redirected_to sign_in_path
    end

    test "should get edit" do
      sign_in_as(@user)
      get edit_password_path
      assert_response :success
    end

    test "should update password" do
      sign_in_as(@user)

      change_password

      assert_redirected_to sessions_path
      assert_equal "Your password has been changed", flash[:notice]
      assert User.authenticate_by(email: @user.email, password: STRONG_PASSWORD)
    end

    test "changing the password signs out other devices but not this one" do
      current = sign_in_as(@user)
      other = @user.sessions.create!

      change_password

      assert_not Session.exists?(other.id)
      assert Session.exists?(current.id)
      assert_signed_in
    end

    test "should not update password with wrong password challenge" do
      sign_in_as(@user)

      change_password(challenge: "SecretWrong1*3")

      assert_response :unprocessable_entity
      assert_select "li", /Password challenge is invalid/
      assert_not User.authenticate_by(email: @user.email, password: STRONG_PASSWORD)
    end

    test "the challenge can't be skipped" do
      sign_in_as(@user)

      patch password_path, params: { password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }

      assert_response :unprocessable_entity
      assert_not User.authenticate_by(email: @user.email, password: STRONG_PASSWORD)
    end

    test "a blank new password is an error, not a silent success" do
      sign_in_as(@user)

      [{ password: "", confirmation: "" }, { password: "   ", confirmation: "   " }].each do |attempt|
        Rails.cache.clear
        change_password(**attempt)

        assert_response :unprocessable_entity
        assert_select "li", /Password can't be blank/
      end
    end

    test "a missing new password is an error" do
      sign_in_as(@user)

      patch password_path, params: { password_challenge: FIXTURE_PASSWORD }

      assert_response :unprocessable_entity
    end

    test "the confirmation has to match" do
      sign_in_as(@user)

      change_password(confirmation: "Different#{STRONG_PASSWORD}")

      assert_response :unprocessable_entity
      assert_select "li", /confirmation/
    end

    test "a pwned password is rejected" do
      sign_in_as(@user)

      with_pwned_count(1234) { change_password }

      assert_response :unprocessable_entity
      assert_select "li", /has been pwned 1234 times/
    end

    test "the change still works when Have I Been Pwned is down" do
      sign_in_as(@user)

      with_pwned_outage { change_password }

      assert_redirected_to sessions_path
    end

    test "attempts are rate limited" do
      sign_in_as(@user)

      3.times { change_password(challenge: "SecretWrong1*3") }
      assert_response :unprocessable_entity

      change_password

      assert_redirected_to edit_password_path
      assert_equal "Too many password change attempts. Try again later.", flash[:alert]
      assert_not User.authenticate_by(email: @user.email, password: STRONG_PASSWORD)
    end
  end
end
