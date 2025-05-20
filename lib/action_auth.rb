require "action_auth/version"
require "action_auth/engine"
require "action_auth/configuration"

module ActionAuth
  class << self
    attr_writer :configuration

    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
      configure_webauthn
    end

    def configure_webauthn
      return unless configuration.webauthn_enabled?
      return unless defined?(WebAuthn)

      WebAuthn.configure do |config|
        config.allowed_origins = if configuration.webauthn_origin.is_a?(Array)
          configuration.webauthn_origin
        else
          [configuration.webauthn_origin]
        end
        config.rp_name = configuration.webauthn_rp_name
      end
    end
  end
end
