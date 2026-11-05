require "test_helper"

module ActionAuth
  class WebauthnCredentialsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = action_auth_users(:one)
    end

    def options_for_new_credential
      post action_auth.options_for_webauthn_credentials_path(format: :json)
      assert_response :success
      response.parsed_body
    end

    def register(client: fake_webauthn_client, nickname: "USB Key", extra: {})
      credential = client.create(challenge: options_for_new_credential["challenge"])
      credential["response"].merge!(extra)
      post_webauthn action_auth.webauthn_credentials_path(credential_nickname: nickname), credential
    end

    test "new requires sign in" do
      get action_auth.new_webauthn_credential_path
      assert_redirected_to action_auth.sign_in_path

      sign_in_as(@user)
      get action_auth.new_webauthn_credential_path
      assert_response :success
    end

    test "options require sign in" do
      post action_auth.options_for_webauthn_credentials_path(format: :json)

      assert_redirected_to action_auth.sign_in_path
    end

    test "create requires sign in" do
      post action_auth.webauthn_credentials_path, params: { format: :json }

      assert_redirected_to action_auth.sign_in_path
    end

    test "destroy requires sign in" do
      delete action_auth.webauthn_credential_path("1")

      assert_redirected_to action_auth.sign_in_path
    end

    test "options assign a stable webauthn id and exclude keys already registered" do
      sign_in_as(@user)
      assert_nil @user.webauthn_id

      first = options_for_new_credential
      webauthn_id = @user.reload.webauthn_id
      assert webauthn_id.present?
      assert_equal webauthn_id, first["user"]["id"]
      assert_empty first["excludeCredentials"]

      register
      assert_response :success

      second = options_for_new_credential
      assert_equal webauthn_id, @user.reload.webauthn_id
      assert_equal @user.webauthn_credentials.pluck(:external_id),
        second["excludeCredentials"].map { |credential| credential["id"] }
    end

    test "asks for a credential that can be used to sign in without a password" do
      sign_in_as(@user)

      assert_equal "preferred", options_for_new_credential.dig("authenticatorSelection", "residentKey")
    end

    test "doesn't use up space on a key when passkey sign in is off" do
      sign_in_as(@user)

      with_action_auth_config(passkey_only: false) do
        assert_nil options_for_new_credential.dig("authenticatorSelection", "residentKey")
      end
    end

    test "registers a key" do
      sign_in_as(@user)

      assert_difference -> { @user.webauthn_credentials.count }, 1 do
        register(nickname: "Yubi & Co")
      end

      assert_response :success
      assert_equal "Yubi & Co", @user.webauthn_credentials.last.nickname
      assert @user.reload.second_factor_enabled?
    end

    test "a nickname is required" do
      sign_in_as(@user)

      assert_no_difference("WebauthnCredential.count") { register(nickname: "") }

      assert_response :unprocessable_entity
      assert_equal "Couldn't add your Security Key", response.body
    end

    test "registering a key someone already registered fails" do
      sign_in_as(@user)
      client = fake_webauthn_client
      existing = client.create(challenge: options_for_new_credential["challenge"])
      create_user_with_credential(webauthn_credential: WebAuthn::Credential.from_create(existing))

      post_webauthn action_auth.webauthn_credentials_path(credential_nickname: "Android"),
        client.create(challenge: options_for_new_credential["challenge"]).merge(existing.slice("id", "rawId"))

      assert_response :unprocessable_entity
    end

    test "registering against a different challenge fails" do
      sign_in_as(@user)
      options_for_new_credential

      assert_no_difference("WebauthnCredential.count") do
        post_webauthn action_auth.webauthn_credentials_path(credential_nickname: "Key"),
          fake_webauthn_client.create(challenge: random_webauthn_challenge)
      end

      assert_response :unprocessable_entity
      assert_equal "Verification failed", response.body
    end

    test "a registration challenge can only be used once" do
      sign_in_as(@user)
      credential = fake_webauthn_client.create(challenge: options_for_new_credential["challenge"])

      post_webauthn action_auth.webauthn_credentials_path(credential_nickname: "Key"), credential
      assert_response :success
      @user.webauthn_credentials.destroy_all

      post_webauthn action_auth.webauthn_credentials_path(credential_nickname: "Key"), credential
      assert_response :unprocessable_entity
    end

    test "malformed payloads are refused rather than crashing" do
      sign_in_as(@user)
      options_for_new_credential

      [{}, { rawId: "not base64!", response: {} }, { id: { a: "b" }, response: "text" }].each do |payload|
        post_webauthn action_auth.webauthn_credentials_path(credential_nickname: "Key"), payload

        assert_response :unprocessable_entity, "for #{payload.inspect}"
      end
    end

    {
      ["internal"] => "passkey",
      ["hybrid", "internal"] => "passkey",
      ["usb"] => "hardware",
      ["nfc", "usb"] => "hardware",
      ["bluetooth"] => "wireless",
      "internal" => "passkey",
      "usb" => "hardware",
      ["carrier-pigeon"] => "unknown",
      "carrier-pigeon" => "unknown",
      [] => "unknown"
    }.each do |transports, key_type|
      test "transports #{transports.inspect} are recorded as #{key_type}" do
        sign_in_as(@user)

        register(extra: { "transports" => transports })

        assert_equal key_type, @user.webauthn_credentials.last.key_type
      end
    end

    test "destroy removes a key" do
      user, = create_user_with_authenticator
      sign_in_as(user)

      delete action_auth.webauthn_credential_path(user.webauthn_credentials.first.id)

      assert_redirected_to action_auth.sessions_path
      assert_response :see_other
      assert_empty user.reload.webauthn_credentials
    end

    test "can't remove someone else's key" do
      other_user, = create_user_with_authenticator(email: "other@example.com")
      sign_in_as(@user)

      delete action_auth.webauthn_credential_path(other_user.webauthn_credentials.first.id)

      assert_response :not_found
      assert_equal 1, other_user.reload.webauthn_credentials.count
    end
  end
end
