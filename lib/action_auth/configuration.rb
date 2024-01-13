module ActionAuth
  class Configuration

    attr_accessor :webauthn_enabled
    attr_accessor :webauthn_origin
    attr_accessor :webauthn_rp_name
    attr_accessor :verify_email_on_sign_in

    def initialize
      @webauthn_enabled = defined?(WebAuthn)
      @webauthn_origin = "http://localhost:3000"
      @webauthn_rp_name = Rails.application.class.to_s.deconstantize
      @verify_email_on_sign_in = true
    end

    def webauthn_enabled?
      @webauthn_enabled.respond_to?(:call) ? @webauthn_enabled.call : @webauthn_enabled
    end

  end
end
