require "test_helper"

module ActionAuth
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
    end

    test "should get index" do
      session = @user.action_auth_sessions.create
      signed_cookies = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
      signed_cookies.signed[:session_token] = { value: session.id, httponly: true }
      cookies[:session_token] = signed_cookies[:session_token]
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
      session = @user.action_auth_sessions.create
      signed_cookies = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
      signed_cookies.signed[:session_token] = { value: session.id, httponly: true }
      cookies[:session_token] = signed_cookies[:session_token]

      delete session_url(@user.action_auth_sessions.last)
      assert_response :redirect
    end
  end
end
