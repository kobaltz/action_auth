require "action_auth/version"
require "action_auth/engine"
require "action_auth/configuration"

module ActionAuth
  class << self
    attr_writer :configuration

    # Initialize configuration with default settings
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?  # Yield only if a block is provided
      configure_webauthn
    end

    def configure_webauthn
      return unless configuration.webauthn_enabled?
      return unless defined?(WebAuthn)

      WebAuthn.configure do |config|
        config.origin = configuration.webauthn_origin
        config.rp_name = configuration.webauthn_rp_name
      end
    end
  end
end
