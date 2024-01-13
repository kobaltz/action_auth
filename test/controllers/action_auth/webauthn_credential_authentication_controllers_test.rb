require 'test_helper'
require "webauthn/fake_client"

module ActionAuth
  class WebauthnCredentialAuthenticationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = action_auth_users(:one)
    end

    test 'new should require initiated login and 2FA enabled' do
      get action_auth.new_webauthn_credential_authentications_path

      assert_redirected_to action_auth.sign_in_path
    end

    test 'new should require user not authenticated' do
      sign_in_as(@user)

      get action_auth.new_webauthn_credential_authentications_path

      assert_redirected_to "/"
    end

    test 'new renders sucessfully' do
      user = create_user_with_credential
      fake_session = { webauthn_user_id: user.id }

      WebauthnCredentialAuthenticationsController.stub_any_instance(:session, fake_session) do
        get action_auth.new_webauthn_credential_authentications_path

        assert_response :success
      end
    end

    test 'create should require initiated login' do
      post action_auth.webauthn_credential_authentications_path

      assert_redirected_to action_auth.sign_in_path
    end

    test 'create should require user not authenticated' do
      sign_in_as(@user)

      post action_auth.webauthn_credential_authentications_path

      assert_redirected_to "/"
    end

    test "successful second factor authentication" do
      raw_challenge = SecureRandom.random_bytes(32)
      challenge = WebAuthn.configuration.encoder.encode(raw_challenge)
      fake_client = WebAuthn::FakeClient.new("http://localhost:3000")
      public_key_credential = fake_client.create(challenge: challenge)
      webauthn_credential = WebAuthn::Credential.from_create(public_key_credential)
      user = create_user_with_credential(webauthn_credential: webauthn_credential)
      fake_session = { webauthn_user_id: user.id, current_challenge: challenge }

      WebauthnCredentialAuthenticationsController.stub_any_instance(:session, fake_session) do
        public_key_credential = fake_client.get(challenge: challenge)

        post(
          action_auth.webauthn_credential_authentications_path,
          params: public_key_credential
        )

        assert_response :success
      end
    end
  end
end
