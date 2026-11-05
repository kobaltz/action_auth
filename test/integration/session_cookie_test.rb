require "test_helper"

# Each way of signing in used to build the cookie by hand, and most got it wrong.
class SessionCookieTest < ActionDispatch::IntegrationTest
  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: true, phone_number: "+15550001111")
  end

  SIGN_IN_PATHS = {
    "password" => ->(test) { test.sign_in_with_password },
    "magic link" => ->(test) { test.sign_in_with_magic_link },
    "SMS code" => ->(test) { test.sign_in_with_sms },
    "passkey" => ->(test) { test.sign_in_with_passkey },
    "security key" => ->(test) { test.sign_in_with_security_key },
    "registration" => ->(test) { test.sign_up_without_verification }
  }.freeze

  def sign_in_with_password
    post action_auth.sign_in_path, params: { email: @user.email, password: FIXTURE_PASSWORD }
  end

  def sign_in_with_magic_link
    get action_auth.magics_sign_ins_path(token: @user.generate_token_for(:magic_token))
  end

  def sign_in_with_sms
    post action_auth.sms_auths_requests_path, params: { phone_number: @user.phone_number }
    post action_auth.sms_auths_sign_ins_path, params: { sms_code: @user.reload.sms_code }
  end

  def sign_in_with_passkey
    _user, client = create_user_with_authenticator(email: "passkey@example.com")
    get action_auth.new_sessions_passkey_path
    post_webauthn action_auth.sessions_passkeys_path,
      client.get(challenge: webauthn_options_on_page["challenge"], user_verified: true)
  end

  def sign_in_with_security_key
    user, client = create_user_with_authenticator(email: "key@example.com")
    post action_auth.sign_in_path, params: { email: user.email, password: STRONG_PASSWORD }
    follow_redirect!
    post_webauthn action_auth.webauthn_credential_authentications_path,
      client.get(challenge: webauthn_options_on_page["challenge"])
  end

  def sign_up_without_verification
    with_action_auth_config(verify_email_on_sign_in: false) do
      post action_auth.sign_up_path, params: { email: "new@example.com", password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }
    end
  end

  SIGN_IN_PATHS.each do |name, sign_in|
    test "#{name} sets httponly and samesite" do
      sign_in.call(self)

      assert_includes set_cookie_attributes, "httponly"
      assert_includes set_cookie_attributes, "samesite=lax"
      assert_not_includes set_cookie_attributes, "secure"
    end

    test "#{name} sets secure on an https request" do
      https!
      with_webauthn_origin("https://www.example.com") { sign_in.call(self) }

      assert_includes set_cookie_attributes, "secure"
    end

    # Rails refuses to send a secure cookie over plain HTTP, so no cookie at all
    # is how this looks from here.
    test "#{name} is secure in production, even if the request isn't" do
      with_rails_env("production") { sign_in.call(self) }

      assert_response_sets_no_cookie "session_token"
    end

    test "#{name} honors insert_cookie_domain" do
      with_action_auth_config(insert_cookie_domain: true) { sign_in.call(self) }

      assert_shared_domain_cookie
    end
  end

  test "signing out deletes a cookie that was set on the whole domain" do
    with_action_auth_config(insert_cookie_domain: true) do
      sign_in_with_password
      assert_shared_domain_cookie

      delete action_auth.session_path(@user.sessions.last)
      assert_shared_domain_cookie
      assert_includes set_cookie_attributes, "max-age=0"
    end
  end

  test "an expired session deletes a cookie that was set on the whole domain" do
    with_action_auth_config(insert_cookie_domain: true) do
      sign_in_with_password

      travel 3.weeks do
        get action_auth.sessions_path

        assert_shared_domain_cookie
        assert_includes set_cookie_attributes, "max-age=0"
      end
    end
  end

  private

  # Rails 8 writes domain=example.com, older versions domain=.example.com
  def assert_shared_domain_cookie
    assert set_cookie_attributes.any? { |attribute| attribute.match?(/\Adomain=\.?example\.com\z/) },
      "expected a whole-domain cookie, got #{set_cookie_attributes.inspect}"
  end

  def assert_response_sets_no_cookie(name)
    headers = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }

    assert_empty headers.select { |line| line.start_with?("#{name}=") }
  end

  def with_webauthn_origin(origin)
    original = WebAuthn.configuration.allowed_origins
    WebAuthn.configuration.allowed_origins = [origin]
    yield
  ensure
    WebAuthn.configuration.allowed_origins = original
  end
end
