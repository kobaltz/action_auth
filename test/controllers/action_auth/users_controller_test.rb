require "test_helper"

module ActionAuth
  class UsersControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = action_auth_users(:one)
    end

    def sign_in_by_sms(phone_number = "+15555550123")
      post sms_auths_requests_url, params: { phone_number: phone_number }
      user = User.find_by!(phone_number: phone_number)
      post sms_auths_sign_ins_url, params: { sms_code: user.sms_code }
      user
    end

    test "requires sign in" do
      assert_no_difference("User.count") { delete users_url, params: { password_challenge: FIXTURE_PASSWORD } }

      assert_redirected_to sign_in_url
    end

    test "the right password deletes only the signed in user, their sessions and their cookie" do
      session = sign_in_as(@user)

      assert_difference("User.count", -1) do
        delete users_url, params: { password_challenge: FIXTURE_PASSWORD }
      end

      assert_response :see_other
      assert_equal "", cookies["session_token"]
      assert_not User.exists?(@user.id)
      assert_not Session.exists?(session.id)
      assert User.exists?(action_auth_users(:two).id)

      follow_redirect!
      assert_match "Your account has been deleted.", response.body
    end

    test "keeps the account without the right password" do
      session = sign_in_as(@user)

      [{ password_challenge: "SecretWrong1*3" }, { password_challenge: "" }, {},
        { password_challenge: [FIXTURE_PASSWORD] }, { password_challenge: { a: FIXTURE_PASSWORD } }].each do |params|
        assert_no_difference("User.count", "for #{params.inspect}") do
          delete users_url, params: params
        end

        assert_response :see_other
        assert_redirected_to sessions_path
        assert_match "wasn't deleted", flash[:alert]
        Rails.cache.clear
      end

      assert Session.exists?(session.id)
      assert_signed_in
    end

    test "another account's password isn't accepted" do
      action_auth_users(:two).update!(password: STRONG_PASSWORD)
      sign_in_as(@user)

      assert_no_difference("User.count") { delete users_url, params: { password_challenge: STRONG_PASSWORD } }
    end

    test "a button with no password field sends people somewhere they can finish" do
      sign_in_as(@user)

      delete users_url
      follow_redirect!

      assert_response :success
      assert_select "[role=alert]", /wasn't deleted/
      assert_select "form[action=?] input[name=password_challenge]", users_path
    end

    test "limits password guesses per session, wherever they come from" do
      sign_in_as(@user)

      5.times do |attempt|
        delete users_url, params: { password_challenge: "SecretWrong1*3" }, env: { "REMOTE_ADDR" => "10.0.0.#{attempt + 1}" }
      end

      assert_no_difference("User.count") do
        delete users_url, params: { password_challenge: FIXTURE_PASSWORD }, env: { "REMOTE_ADDR" => "10.0.0.99" }
      end

      assert_redirected_to sessions_path
      assert_equal "Too many attempts. Try again later.", flash[:alert]
    end

    test "deleting an account removes its security keys" do
      user, = create_user_with_authenticator
      sign_in_as(user)

      assert_difference("WebauthnCredential.count", -1) { delete users_url, params: { password_challenge: STRONG_PASSWORD } }
    end

    test "goes to the configured path" do
      sign_in_as(@user)

      with_action_auth_config(after_sign_out_path: "/goodbye") do
        delete users_url, params: { password_challenge: FIXTURE_PASSWORD }
      end

      assert_redirected_to "/goodbye"
    end

    test "the management screen asks for the password" do
      sign_in_as(@user)

      get sessions_url

      assert_select "form[action=?]", users_path do
        assert_select "input[type=password][name=password_challenge][required]"
      end
      assert_select "a[href=?]", new_identity_password_reset_path
    end

    test "an account made by SMS can be deleted right after signing in with a code" do
      user = sign_in_by_sms
      assert_signed_in
      assert_not user.password_usable?

      assert_difference("User.count", -1) { delete users_url }

      assert_equal "", cookies["session_token"]
    end

    test "an account made by SMS can still be deleted near the end of the 10 minutes" do
      sign_in_by_sms

      travel 9.minutes

      assert_difference("User.count", -1) { delete users_url }
    end

    test "an account made by SMS has to sign in again once its code is no longer recent" do
      user = sign_in_by_sms

      # Using the site moves the session's updated_at, which mustn't count as signing in.
      travel 9.minutes
      get sessions_url
      assert_equal Time.current.to_i, user.sessions.last.updated_at.to_i

      travel 2.minutes
      assert_no_difference("User.count") { delete users_url }

      assert_redirected_to sessions_path
      assert_match "new SMS code", flash[:alert]
      assert_signed_in
    end

    test "the management screen doesn't ask an account made by SMS for a password" do
      sign_in_by_sms

      get sessions_url

      assert_select "form[action=?]", users_path do
        assert_select "input[name=password_challenge]", count: 0
      end
      assert_select "a[href=?]", new_identity_password_reset_path, count: 0
      assert_match "new SMS code", response.body
    end

    test "an account with a phone number and a real email still needs its password" do
      @user.update!(phone_number: "+15555550124")
      sign_in_as(@user)

      assert_no_difference("User.count") { delete users_url }
    end
  end
end
