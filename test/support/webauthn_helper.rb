require "webauthn/fake_client"

# Drives WebAuthn the way a browser does: the challenge comes from the page the
# server rendered, and the signed response goes back as JSON.
module WebauthnHelper
  def fake_webauthn_client
    WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first)
  end

  def random_webauthn_challenge
    WebAuthn.configuration.encoder.encode(SecureRandom.random_bytes(32))
  end

  # Returns [user, client], where client holds the user's private key.
  def create_user_with_authenticator(email: "user@example.com", verified: true)
    client = fake_webauthn_client
    credential = WebAuthn::Credential.from_create(client.create(challenge: random_webauthn_challenge))
    user = create_user_with_credential(email: email, webauthn_credential: credential)
    user.update!(verified: verified)
    [user, client]
  end

  def webauthn_options_on_page
    form = css_select("#webauthn_credential_form").first
    assert form, "expected the page to contain the WebAuthn form"

    JSON.parse(form["data-credential-authenticator-options-value"])
  end

  def post_webauthn(path, payload)
    post path, params: payload, as: :json
  end
end
