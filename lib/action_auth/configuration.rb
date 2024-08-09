module ActionAuth
  class Configuration

    attr_accessor :allow_user_deletion
    attr_accessor :default_from_email
    attr_accessor :magic_link_enabled
    attr_accessor :verify_email_on_sign_in
    attr_accessor :webauthn_enabled
    attr_accessor :webauthn_origin
    attr_accessor :webauthn_rp_name


    def initialize
      @allow_user_deletion = true
      @default_from_email = "from@example.com"
      @magic_link_enabled = true
      @verify_email_on_sign_in = true
      @webauthn_enabled = defined?(WebAuthn)
      @webauthn_origin = "http://localhost:3000"
      @webauthn_rp_name = Rails.application.class.to_s.deconstantize
    end

    def allow_user_deletion?
      @allow_user_deletion.respond_to?(:call) ? @allow_user_deletion.call : @allow_user_deletion
    end

    def magic_link_enabled?
      @magic_link_enabled.respond_to?(:call) ? @magic_link_enabled.call : @magic_link_enabled
    end

    def webauthn_enabled?
      @webauthn_enabled.respond_to?(:call) ? @webauthn_enabled.call : @webauthn_enabled
    end

  end
end
