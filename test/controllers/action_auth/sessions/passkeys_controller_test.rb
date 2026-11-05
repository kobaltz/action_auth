require "test_helper"

module ActionAuth
  class Sessions::PasskeysControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user, @client = create_user_with_authenticator(email: "passkey@example.com")
    end

    def assertion_for_page_challenge(**options)
      get action_auth.new_sessions_passkey_path
      assert_response :success
      @client.get(challenge: webauthn_options_on_page["challenge"], user_verified: true, **options)
    end

    test "new asks the browser for user verification" do
      get action_auth.new_sessions_passkey_path

      assert_response :success
      assert_equal "required", webauthn_options_on_page["userVerification"]
    end

    test "a valid passkey signs in" do
      assertion = assertion_for_page_challenge

      assert_difference -> { @user.sessions.count }, 1 do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_response :success
      assert_equal "/", response.parsed_body["redirect_url"]
      assert_signed_in
    end

    test "a valid passkey updates the stored sign count" do
      assertion = assertion_for_page_challenge(sign_count: 7)

      post_webauthn action_auth.sessions_passkeys_path, assertion

      assert_equal 7, @user.webauthn_credentials.reload.first.sign_count
    end

    test "a cloned authenticator is rejected by the sign count check" do
      @user.webauthn_credentials.first.update!(sign_count: 10)
      assertion = assertion_for_page_challenge(sign_count: 5)

      post_webauthn action_auth.sessions_passkeys_path, assertion

      assert_response :unprocessable_entity
      assert_signed_out
    end

    test "sends people to the configured path" do
      assertion = assertion_for_page_challenge

      with_action_auth_config(after_sign_in_path: "/dashboard") do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_equal "/dashboard", response.parsed_body["redirect_url"]
    end

    test "a forged signature does not sign in" do
      assertion = assertion_for_page_challenge
      assertion["response"]["signature"] = WebAuthn.configuration.encoder.encode("not a real signature")

      assert_no_difference -> { Session.count } do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_response :unprocessable_entity
      assert_equal "That passkey is incorrect", response.body
      assert_signed_out
    end

    test "an assertion signed over a different challenge does not sign in" do
      get action_auth.new_sessions_passkey_path
      assertion = @client.get(challenge: random_webauthn_challenge, user_verified: true)

      assert_no_difference -> { Session.count } do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_response :unprocessable_entity
    end

    test "an assertion does not sign in when no challenge was issued" do
      assertion = @client.get(challenge: random_webauthn_challenge, user_verified: true)

      assert_no_difference -> { Session.count } do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_response :unprocessable_entity
    end

    # Synced passkeys always report a sign count of 0, which leaves the challenge
    # as the only thing stopping a captured assertion being replayed.
    test "a challenge can only be used once" do
      assertion = assertion_for_page_challenge(sign_count: 0)
      post_webauthn action_auth.sessions_passkeys_path, assertion
      assert_response :success

      cookies.delete("session_token")

      assert_no_difference -> { Session.count } do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end
      assert_response :unprocessable_entity
    end

    test "a passkey that didn't verify the user does not sign in" do
      assertion = assertion_for_page_challenge(user_verified: false)

      assert_no_difference -> { Session.count } do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_response :unprocessable_entity
    end

    test "a credential nobody registered does not sign in" do
      get action_auth.new_sessions_passkey_path
      challenge = webauthn_options_on_page["challenge"]
      stranger = fake_webauthn_client
      stranger.create(challenge: challenge)

      post_webauthn action_auth.sessions_passkeys_path, stranger.get(challenge: challenge, user_verified: true)

      assert_response :unprocessable_entity
      assert_signed_out
    end

    test "a credential without a user does not sign in" do
      assertion = assertion_for_page_challenge
      @user.webauthn_credentials.first.update!(user_id: nil)

      assert_no_difference -> { Session.count } do
        post_webauthn action_auth.sessions_passkeys_path, assertion
      end

      assert_response :unprocessable_entity
    end

    test "malformed payloads are refused rather than crashing" do
      get action_auth.new_sessions_passkey_path

      [
        {},
        { id: "x", rawId: "not base64!", type: "public-key", response: {} },
        { id: "x", rawId: "eA", type: "public-key", response: { clientDataJSON: "eA", authenticatorData: "eA", signature: "eA" } },
        { id: { nested: "x" }, rawId: { nested: "x" }, response: "text" }
      ].each do |payload|
        post_webauthn action_auth.sessions_passkeys_path, payload
        assert_response :unprocessable_entity, "for #{payload.inspect}"
      end
    end

    test "attempts are rate limited" do
      5.times { post_webauthn action_auth.sessions_passkeys_path, {} }
      assert_response :unprocessable_entity

      post_webauthn action_auth.sessions_passkeys_path, {}
      assert_response :too_many_requests
    end
  end
end
