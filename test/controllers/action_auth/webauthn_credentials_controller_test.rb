require 'test_helper'
require "webauthn/fake_client"

class WebauthnCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = action_auth_users(:one)
  end

  test 'new should require authentication' do
    get action_auth.new_webauthn_credential_path
    assert_redirected_to action_auth.sign_in_path

    sign_in_as(@user)
    get action_auth.new_webauthn_credential_path
    assert_response :success
  end

  test 'options should require authentication' do
    post action_auth.options_for_webauthn_credentials_path, params: { credentials: { nickname: 'USB Key' }, format: :json }

    assert_redirected_to action_auth.sign_in_path
  end

  test 'create should require authentication' do
    post action_auth.webauthn_credentials_path, params: { credentials: { nickname: 'USB Key' }, format: :json }

    assert_redirected_to action_auth.sign_in_path
  end

  test 'should initiate credential creation successfully' do
    sign_in_as(@user)

    post action_auth.options_for_webauthn_credentials_path, params: { credentials: { nickname: 'USB Key' }, format: :json }

    assert_response :success
  end

  test "should return error if registering existing credential" do
    raw_challenge = SecureRandom.random_bytes(32)
    challenge = WebAuthn.configuration.encoder.encode(raw_challenge)
    sign_in_as(@user)

    WebAuthn::PublicKeyCredential::CreationOptions.stub_any_instance(:raw_challenge, raw_challenge) do
      post action_auth.options_for_webauthn_credentials_path, params: { format: :json }

      assert_response :success
    end

    public_key_credential = WebAuthn::FakeClient.new("http://localhost:3000").create(challenge: challenge)
    webauthn_credential = WebAuthn::Credential.from_create(public_key_credential)
    create_user_with_credential(credential_nickname: 'USB Key', webauthn_credential: webauthn_credential)

    post(
      action_auth.webauthn_credentials_path,
      params: { credential_nickname: 'Android Phone' }.merge(public_key_credential)
    )

    assert_response :unprocessable_entity
    assert_equal "Couldn't add your Security Key", response.body
  end

  test 'destroy should require authentication' do
    delete action_auth.webauthn_credential_path('1')

    assert_redirected_to action_auth.sign_in_path
  end

  test 'destroy should work' do
    raw_registration_challenge = SecureRandom.random_bytes(32)
    registration_challenge = WebAuthn.configuration.encoder.encode(raw_registration_challenge)
    fake_client = WebAuthn::FakeClient.new("http://localhost:3000")
    public_key_credential = fake_client.create(challenge: registration_challenge)
    webauthn_credential = WebAuthn::Credential.from_create(public_key_credential)
    user = create_user_with_credential(webauthn_credential: webauthn_credential)
    sign_in_as(user)

    raw_authentication_challenge = SecureRandom.random_bytes(32)
    authentication_challenge = WebAuthn.configuration.encoder.encode(raw_authentication_challenge)

    public_key_credential = fake_client.get(challenge: authentication_challenge)
    post(action_auth.webauthn_credential_authentications_path, params: public_key_credential)
    delete action_auth.webauthn_credential_path(user.action_auth_webauthn_credentials.first.id)

    assert_redirected_to action_auth.sessions_path
    assert_empty user.reload.action_auth_webauthn_credentials
  end

  private

  def user
    @user ||= User.create!(username: 'alice', password: 'foo')
  end
end
