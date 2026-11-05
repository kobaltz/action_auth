require "test_helper"

module ActionAuth
  class WebauthnCredentialAuthenticationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user, @client = create_user_with_authenticator
    end

    def start_second_factor
      post action_auth.sign_in_path, params: { email: @user.email, password: STRONG_PASSWORD }
      assert_redirected_to action_auth.new_webauthn_credential_authentications_path
      follow_redirect!
      assert_response :success
    end

    test "new requires a password sign in first" do
      get action_auth.new_webauthn_credential_authentications_path

      assert_redirected_to action_auth.sign_in_path
    end

    test "new sends people who are already signed in to the app" do
      sign_in_as(@user)

      get action_auth.new_webauthn_credential_authentications_path

      assert_redirected_to "/"
    end

    test "new only offers the user's own keys" do
      start_second_factor

      expected = @user.webauthn_credentials.pluck(:external_id)
      assert_equal expected, webauthn_options_on_page["allowCredentials"].map { |credential| credential["id"] }
    end

    test "new copes with the user disappearing partway through" do
      post action_auth.sign_in_path, params: { email: @user.email, password: STRONG_PASSWORD }
      @user.destroy!

      get action_auth.new_webauthn_credential_authentications_path

      assert_redirected_to action_auth.sign_in_path
    end

    test "create requires a password sign in first" do
      post action_auth.webauthn_credential_authentications_path

      assert_redirected_to action_auth.sign_in_path
    end

    test "create sends people who are already signed in to the app" do
      sign_in_as(@user)

      post action_auth.webauthn_credential_authentications_path

      assert_redirected_to "/"
    end

    test "password then security key signs in" do
      start_second_factor
      assertion = @client.get(challenge: webauthn_options_on_page["challenge"])

      assert_difference -> { @user.sessions.count }, 1 do
        post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      end

      assert_response :success
      assert_equal "ok", response.parsed_body["status"]
      assert_equal "/", response.parsed_body["redirect_url"]
      assert_signed_in
    end

    test "sends people to the configured path" do
      start_second_factor
      assertion = @client.get(challenge: webauthn_options_on_page["challenge"])

      with_action_auth_config(after_sign_in_path: "/dashboard") do
        post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      end

      assert_equal "/dashboard", response.parsed_body["redirect_url"]
    end

    test "updates the stored sign count" do
      start_second_factor

      post_webauthn action_auth.webauthn_credential_authentications_path,
        @client.get(challenge: webauthn_options_on_page["challenge"], sign_count: 9)

      assert_equal 9, @user.webauthn_credentials.reload.first.sign_count
    end

    test "a forged signature does not sign in" do
      start_second_factor
      assertion = @client.get(challenge: webauthn_options_on_page["challenge"])
      assertion["response"]["signature"] = WebAuthn.configuration.encoder.encode("not a real signature")

      assert_no_difference("Session.count") do
        post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      end

      assert_response :unprocessable_entity
      assert_equal "Verification failed", response.body
    end

    test "an assertion signed over a different challenge does not sign in" do
      start_second_factor

      assert_no_difference("Session.count") do
        post_webauthn action_auth.webauthn_credential_authentications_path,
          @client.get(challenge: random_webauthn_challenge)
      end

      assert_response :unprocessable_entity
    end

    # A sign count of 0 means the sign count check can't catch this replay.
    test "a challenge can only be used once" do
      start_second_factor
      assertion = @client.get(challenge: webauthn_options_on_page["challenge"], sign_count: 0)
      post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      assert_response :success

      cookies.delete("session_token")
      post action_auth.sign_in_path, params: { email: @user.email, password: STRONG_PASSWORD }

      assert_no_difference("Session.count") do
        post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      end
      assert_response :unprocessable_entity
    end

    test "a failed attempt uses up the challenge too" do
      start_second_factor
      assertion = @client.get(challenge: webauthn_options_on_page["challenge"], sign_count: 0)
      good_signature = assertion["response"]["signature"]
      assertion["response"]["signature"] = WebAuthn.configuration.encoder.encode("not a real signature")
      post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      assert_response :unprocessable_entity

      assertion["response"]["signature"] = good_signature

      assert_no_difference("Session.count") do
        post_webauthn action_auth.webauthn_credential_authentications_path, assertion
      end
      assert_response :unprocessable_entity
    end

    test "someone else's key does not work" do
      other_user, other_client = create_user_with_authenticator(email: "other@example.com")
      start_second_factor

      assert_no_difference("Session.count") do
        post_webauthn action_auth.webauthn_credential_authentications_path,
          other_client.get(challenge: webauthn_options_on_page["challenge"])
      end

      assert_response :unprocessable_entity
      assert_equal 0, other_user.sessions.count
    end

    test "malformed payloads are refused rather than crashing" do
      start_second_factor

      [{}, { rawId: "not base64!", response: {} }, { id: { a: "b" }, response: "text" }].each do |payload|
        post_webauthn action_auth.webauthn_credential_authentications_path, payload

        assert_response :unprocessable_entity, "for #{payload.inspect}"
      end
    end

    test "attempts are rate limited" do
      start_second_factor

      5.times { post_webauthn action_auth.webauthn_credential_authentications_path, {} }
      assert_response :unprocessable_entity

      post_webauthn action_auth.webauthn_credential_authentications_path, {}
      assert_response :too_many_requests
    end
  end
end
