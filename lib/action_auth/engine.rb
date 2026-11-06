require 'action_auth/controllers/helpers'
require 'action_auth/routing/helpers'

module ActionAuth
  class Engine < ::Rails::Engine
    isolate_namespace ActionAuth

    ActiveSupport.on_load(:action_controller_base) do
      include ActionAuth::Controllers::Helpers
      include ActionAuth::Routing::Helpers
    end

    initializer 'action_auth.add_helpers' do |app|
      ActiveSupport.on_load :action_controller_base do
        helper_method :user_sessions_path, :user_session_path, :new_user_session_path
        helper_method :new_user_registration_path
        helper_method :edit_user_password_path, :user_password_path
      end
    end

    # Propshaft picks up engine assets by itself; Sprockets needs to be told.
    initializer 'action_auth.assets' do |app|
      app.config.assets.precompile << "action_auth_manifest.js" if defined?(Sprockets::Rails)
    end

    # OmniAuth runs inside the engine, so its paths follow wherever the app mounts
    # ActionAuth and the rest of the app never goes through it.
    initializer 'action_auth.oauth', after: :load_config_initializers do
      next unless ActionAuth.configuration.oauth_enabled?

      OmniAuth.config.logger = Rails.logger

      config.middleware.use(OmniAuth::Builder) do
        ActionAuth.configuration.oauth_providers.each do |oauth|
          provider(oauth.strategy, *oauth.args, **oauth.options)
        end
      end
    end

    # An app that keeps the generated, fully commented out initializer never
    # calls ActionAuth.configure, but still gets WebAuthn routes if the gem is
    # installed. Those need the origin set too.
    config.after_initialize do
      ActionAuth.configure_webauthn
    end
  end
end
