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

  # OmniAuth's built in form, which needs no provider to talk to.
  config.oauth_provider :developer, label: "Developer"
  config.oauth_provider :developer, name: "other", label: "Other"

  # test/support/host_parent_controller_check.rb runs the app in this mode.
  if ENV["ACTION_AUTH_HOST_PARENT_CONTROLLER"].present?
    config.parent_controller = "ApplicationController"
    config.layout = "with_host_helper"
  end
end

Rails.application.config.after_initialize do
  ActionAuth.configure do |config|
    config.sms_send_class = SmsSender
  end
end
