module ActionAuth
  class Configuration
    OAUTH_PROVIDER_LABELS = {
      "facebook" => "Facebook",
      "github" => "GitHub",
      "google_oauth2" => "Google",
      "twitter" => "Twitter",
      "twitter2" => "X"
    }.freeze

    # One OmniAuth strategy and the arguments to start it with. The key is what
    # OmniAuth calls it, and appears in its paths: auth/:key and auth/:key/callback.
    OauthProvider = Struct.new(:strategy, :args, :options, :label) do
      def key
        (options[:name] || strategy).to_s
      end
    end

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

    # Temporarily stops password and SMS code sign in after too many failures in a
    # row. A nil duration keeps the account locked until it's unlocked or the
    # password is reset.
    attr_accessor :account_lockout_enabled
    attr_accessor :account_lockout_max_attempts
    attr_accessor :account_lockout_duration

    # Lets your app block an account from signing in at all, with
    # user.suspend_account!. ActionAuth never suspends anyone by itself.
    attr_accessor :account_suspension_enabled

    # Sign in through other sites. Needs the omniauth gem and at least one
    # config.oauth_provider. Must be set in an initializer, not in an
    # after_initialize block, because the routes depend on it.
    attr_accessor :oauth_enabled
    attr_reader :oauth_providers

    attr_accessor :insert_cookie_domain

    # The layout for ActionAuth's screens, e.g. "application". The default (nil)
    # uses layouts/action_auth/application, which an app can also override by
    # creating that file.
    attr_accessor :layout

    # The class ActionAuth's controllers inherit from, as a String. Set this to
    # "ApplicationController" when a custom layout or view needs your app's
    # helpers. Must be set in an initializer, not in an after_initialize block.
    attr_accessor :parent_controller

    # Where to send people after signing in and out. Either a path String or a
    # Proc evaluated in the controller, e.g. -> { main_app.dashboard_path }.
    # The default (nil) is your app's root path.
    attr_accessor :after_sign_in_path
    attr_accessor :after_sign_out_path

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

      @account_lockout_enabled = true
      @account_lockout_max_attempts = 10
      @account_lockout_duration = 30.minutes
      @account_suspension_enabled = true

      @oauth_enabled = defined?(OmniAuth)
      @oauth_providers = []

      @insert_cookie_domain = false

      @layout = nil
      @parent_controller = "ActionController::Base"
      @after_sign_in_path = nil
      @after_sign_out_path = nil
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

    # The webauthn and pwned gems are optional, so these can only be on when the
    # gem is actually loaded, whatever the initializer says.
    def webauthn_enabled?
      return false unless defined?(WebAuthn)

      @webauthn_enabled.respond_to?(:call) ? @webauthn_enabled.call : @webauthn_enabled
    end

    def pwned_enabled?
      return false unless defined?(Pwned)

      @pwned_enabled.respond_to?(:call) ? @pwned_enabled.call : @pwned_enabled
    end

    def password_complexity_check?
      @password_complexity_check == true
    end

    def account_lockout_enabled?
      @account_lockout_enabled == true
    end

    def account_suspension_enabled?
      @account_suspension_enabled == true
    end

    # Adds a provider. Takes the same arguments as OmniAuth's provider method,
    # plus an optional label for the buttons:
    #
    #   config.oauth_provider :github, ENV["GITHUB_ID"], ENV["GITHUB_SECRET"], scope: "user:email"
    def oauth_provider(strategy, *args, label: nil, **options)
      provider = OauthProvider.new(strategy, args, options)
      provider.label = label || OAUTH_PROVIDER_LABELS.fetch(provider.key) { provider.key.titleize }

      @oauth_providers.reject! { |existing| existing.key == provider.key }
      @oauth_providers << provider
    end

    # Having the gem isn't enough, since an app may use OmniAuth for something of
    # its own. It takes a provider added here for ActionAuth to get involved.
    def oauth_enabled?
      return false unless defined?(OmniAuth)
      return false if @oauth_providers.empty?

      @oauth_enabled.respond_to?(:call) ? @oauth_enabled.call : @oauth_enabled
    end

  end
end
