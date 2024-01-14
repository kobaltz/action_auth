require "action_auth/version"
require "action_auth/engine"
require "action_auth/configuration"

module ActionAuth
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration)
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
