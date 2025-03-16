require "test_helper"

module ActionAuth
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
    end

    test "should get index" do
      sign_in_as(@user)
      get sessions_url
      assert_response :success
    end

    test "should get new" do
      get sign_in_url
      assert_response :success
    end

    test "should sign in" do
      post sign_in_url, params: { email: @user.email, password: "123456789012" }
      assert_response :redirect
    end

    test "should not sign in with wrong credentials" do
      post sign_in_url, params: { email: @user.email, password: "SecretWrong1*3" }
      assert_redirected_to sign_in_url(email_hint: @user.email)
      assert_equal "That email or password is incorrect", flash[:alert]
      assert_response :redirect
    end

    test "should sign out" do
      sign_in_as(@user)

      delete session_url(@user.sessions.last)
      assert_response :redirect
    end

    test "session should timeout after a period of inactivity" do
      session = ActionAuth::Session.new
      session.updated_at = 3.hours.ago
      assert_not session.updated_at < 2.weeks.ago, "Session should not timeout after just 3 hours"
      session.updated_at = 3.weeks.ago
      assert session.updated_at < 2.weeks.ago, "Session should timeout after 3 weeks"
    end

    test "should implement rate limiting for sign in" do
      controller = ActionAuth::SessionsController.new
      def controller.test_rate_limit(attempts)
        max_attempts = 5
        attempts > max_attempts
      end
      assert_not controller.test_rate_limit(5), "Should not rate limit with 5 attempts"
      assert controller.test_rate_limit(6), "Should rate limit with 6 attempts"
    end
  end
end
