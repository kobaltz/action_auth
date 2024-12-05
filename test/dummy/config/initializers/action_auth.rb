ActionAuth.configure do |config|
  config.allow_user_deletion = true
  config.default_from_email = "from@example.com"
  config.magic_link_enabled = true
  config.passkey_only = true # Allows sign in with only a passkey
  config.pwned_enabled = true # defined?(Pwned)
  config.sms_auth_enabled = true
  config.verify_email_on_sign_in = true
  config.webauthn_enabled = true # defined?(WebAuthn)
  config.webauthn_origin = "http://localhost:3000" # or "https://example.com"
  config.webauthn_rp_name = Rails.application.class.to_s.deconstantize
  config.insert_cookie_domain = false
end

Rails.application.config.after_initialize do
  ActionAuth.configure do |config|
    config.sms_send_class = SmsSender
  end
end
