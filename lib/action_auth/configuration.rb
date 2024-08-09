module ActionAuth
  class Configuration

    attr_accessor :webauthn_enabled
    attr_accessor :webauthn_origin
    attr_accessor :webauthn_rp_name
    attr_accessor :verify_email_on_sign_in
    attr_accessor :magic_link_enabled
    attr_accessor :default_from_email

    def initialize
      @webauthn_enabled = defined?(WebAuthn)
      @webauthn_origin = "http://localhost:3000"
      @webauthn_rp_name = Rails.application.class.to_s.deconstantize
      @verify_email_on_sign_in = true
      @magic_link_enabled = false
      @default_from_email = "from@example.com"
    end

    def webauthn_enabled?
      @webauthn_enabled.respond_to?(:call) ? @webauthn_enabled.call : @webauthn_enabled
    end

    def magic_link_enabled?
      @magic_link_enabled.respond_to?(:call) ? @magic_link_enabled.call : @magic_link_enabled
    end

  end
end
