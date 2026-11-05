require "test_helper"

module ActionAuth
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
      @user.update!(verified: true)
    end

    test "index requires sign in" do
      get sessions_url
      assert_redirected_to sign_in_url
    end

    test "index lists the user's sessions and marks this device" do
      current = sign_in_as(@user)
      other = @user.sessions.create!

      get sessions_url

      assert_response :success
      assert_select "tr#session_#{current.id}", /this device/
      assert_select "tr#session_#{other.id}"
      assert_select "tr#session_#{other.id}", text: /this device/, count: 0
    end

    test "should get new" do
      get sign_in_url
      assert_response :success
    end

    test "new fills in the email hint" do
      get sign_in_url(email_hint: "hint@example.com")
      assert_select "input[name=email][value=?]", "hint@example.com"
    end

    test "signs in and goes to the app" do
      assert_difference -> { @user.sessions.count }, 1 do
        post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD }
      end

      assert_redirected_to "/"
      assert_equal "Signed in successfully", flash[:notice]
      assert_signed_in
    end

    test "email is matched regardless of case and surrounding whitespace" do
      post sign_in_url, params: { email: "  #{@user.email.upcase} ", password: FIXTURE_PASSWORD }

      assert_signed_in
    end

    test "records the device on the session" do
      post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD },
        headers: { "User-Agent" => "TestBrowser/1.0" }

      assert_equal "TestBrowser/1.0", @user.sessions.last.user_agent
      assert_equal "127.0.0.1", @user.sessions.last.ip_address
    end

    test "sends people to the configured path" do
      with_action_auth_config(after_sign_in_path: "/dashboard") do
        post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD }
      end

      assert_redirected_to "/dashboard"
    end

    test "a wrong password does not sign in" do
      assert_no_difference -> { Session.count } do
        post sign_in_url, params: { email: @user.email, password: "SecretWrong1*3" }
      end

      assert_redirected_to sign_in_url(email_hint: @user.email)
      assert_equal "That email or password is incorrect", flash[:alert]
    end

    test "an unknown email looks the same as a wrong password" do
      post sign_in_url, params: { email: "nobody@example.com", password: "SecretWrong1*3" }

      assert_equal "That email or password is incorrect", flash[:alert]
    end

    test "missing or non-string credentials are treated as wrong" do
      [
        {},
        { email: @user.email },
        { email: [@user.email], password: [FIXTURE_PASSWORD] },
        { email: { a: "b" }, password: { a: "b" } }
      ].each do |credentials|
        Rails.cache.clear
        post sign_in_url, params: credentials

        assert_response :redirect, "for #{credentials.inspect}"
        assert_equal "That email or password is incorrect", flash[:alert]
      end
      assert_signed_out
    end

    test "an unverified email can't sign in" do
      @user.update!(verified: false)

      assert_no_difference -> { Session.count } do
        post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD }
      end

      assert_equal "You must verify your email before you sign in.", flash[:alert]
    end

    test "an unverified email can sign in when verification is turned off" do
      @user.update!(verified: false)

      with_action_auth_config(verify_email_on_sign_in: false) do
        post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD }
      end

      assert_signed_in
    end

    test "an account with a security key is sent to the second factor" do
      user, = create_user_with_authenticator

      assert_no_difference -> { Session.count } do
        post sign_in_url, params: { email: user.email, password: STRONG_PASSWORD }
      end

      assert_redirected_to new_webauthn_credential_authentications_url
      assert_signed_out
    end

    test "an unverified account with a security key can't start the second factor" do
      user, = create_user_with_authenticator(verified: false)

      post sign_in_url, params: { email: user.email, password: STRONG_PASSWORD }

      assert_equal "You must verify your email before you sign in.", flash[:alert]
    end

    test "signing out ends the session and removes the cookie" do
      current = sign_in_as(@user)

      delete session_url(current)

      assert_redirected_to "/"
      assert_response :see_other
      assert_not Session.exists?(current.id)
      assert_equal "", cookies["session_token"]
      assert_equal '"cache","storage"', response.headers["Clear-Site-Data"]
      assert_signed_out
    end

    test "signing out goes to the configured path" do
      current = sign_in_as(@user)

      with_action_auth_config(after_sign_out_path: "/goodbye") do
        delete session_url(current)
      end

      assert_redirected_to "/goodbye"
    end

    test "logging out another device keeps this one signed in" do
      sign_in_as(@user)
      other = @user.sessions.create!

      delete session_url(other)

      assert_redirected_to sessions_url
      assert_not Session.exists?(other.id)
      assert_nil response.headers["Clear-Site-Data"]
      assert_signed_in
    end

    test "can't log out someone else's session" do
      sign_in_as(@user)
      someone_else = action_auth_users(:two).sessions.create!

      delete session_url(someone_else)

      assert_response :not_found
      assert Session.exists?(someone_else.id)
    end

    test "signing out requires sign in" do
      delete session_url(action_auth_sessions(:one))

      assert_redirected_to sign_in_url
      assert Session.exists?(action_auth_sessions(:one).id)
    end

    test "a session expires after the configured period of inactivity" do
      session = sign_in_as(@user)

      travel 2.weeks + 1.minute do
        get sessions_url

        assert_redirected_to sign_in_url
        assert_equal "Your session has expired. Please sign in again.", flash[:alert]
        assert_not Session.exists?(session.id)
      end
    end

    test "activity keeps a session alive" do
      sign_in_as(@user)

      travel 10.days do
        assert_signed_in
      end
      travel 20.days do
        assert_signed_in
      end
    end

    test "a request shortly after the last doesn't write to the session" do
      session = sign_in_as(@user)

      assert_no_changes -> { session.reload.updated_at } do
        travel(30.seconds) { assert_signed_in }
      end
    end

    test "a request after a while refreshes the session" do
      session = sign_in_as(@user)

      assert_changes -> { session.reload.updated_at } do
        travel(2.minutes) { assert_signed_in }
      end
    end

    test "sessions don't expire when the timeout is turned off" do
      sign_in_as(@user)

      with_action_auth_config(session_timeout: nil) do
        travel(10.years) { assert_signed_in }
      end
    end

    test "sign in attempts are rate limited" do
      5.times { post sign_in_url, params: { email: @user.email, password: "SecretWrong1*3" } }
      assert_equal "That email or password is incorrect", flash[:alert]

      post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD }

      assert_redirected_to sign_in_url
      assert_equal "Try again later.", flash[:alert]
      assert_signed_out
    end

    test "the rate limit resets after the window" do
      6.times { post sign_in_url, params: { email: @user.email, password: "SecretWrong1*3" } }

      travel 21.seconds do
        post sign_in_url, params: { email: @user.email, password: FIXTURE_PASSWORD }
        assert_equal "Signed in successfully", flash[:notice]
      end
    end
  end
end
