module ActionAuth
  class Configuration

    attr_accessor :allow_user_deletion
    attr_accessor :default_from_email
    attr_accessor :magic_link_enabled
    attr_accessor :passkey_only
    attr_accessor :pwned_enabled
    attr_accessor :sms_auth_enabled
    attr_accessor :sms_send_class
    attr_accessor :verify_email_on_sign_in
    attr_accessor :webauthn_enabled
    attr_accessor :webauthn_origin
    attr_accessor :webauthn_rp_name
    attr_accessor :password_complexity_check
    attr_accessor :session_timeout

    attr_accessor :insert_cookie_domain

    def initialize
      @allow_user_deletion = true
      @default_from_email = Rails.application.config.action_mailer.default_options&.dig(:from) || "noreply@#{ENV['HOST'] || 'example.com'}"
      @magic_link_enabled = true
      @passkey_only = true
      @pwned_enabled = defined?(Pwned)
      @password_complexity_check = true
      @sms_auth_enabled = false
      @sms_send_class = nil
      @verify_email_on_sign_in = true
      @webauthn_enabled = defined?(WebAuthn)
      @webauthn_origin = Rails.env.production? ? "https://#{ENV['HOST']}" : "http://localhost:3000"
      @webauthn_rp_name = Rails.application.class.to_s.deconstantize
      @session_timeout = 2.weeks

      @insert_cookie_domain = false
    end

    def allow_user_deletion?
      @allow_user_deletion == true
    end

    def magic_link_enabled?
      @magic_link_enabled == true
    end

    def sms_auth_enabled?
      @sms_auth_enabled == true
    end

    def passkey_only?
      webauthn_enabled? && @passkey_only == true
    end

    def webauthn_enabled?
      @webauthn_enabled.respond_to?(:call) ? @webauthn_enabled.call : @webauthn_enabled
    end

    def pwned_enabled?
      @pwned_enabled.respond_to?(:call) ? @pwned_enabled.call : @pwned_enabled
    end

    def password_complexity_check?
      @password_complexity_check == true
    end

  end
end
