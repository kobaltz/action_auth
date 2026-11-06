require 'test_helper'

module ActionAuth
  class ConfigurationTest < ActiveSupport::TestCase
    def setup
      @config = Configuration.new
    end

    test 'should initialize with default values' do
      assert_equal defined?(WebAuthn), @config.webauthn_enabled
      assert_equal 'http://localhost:3000', @config.webauthn_origin
      assert_equal Rails.application.class.to_s.deconstantize, @config.webauthn_rp_name
      assert_equal 2.weeks, @config.session_timeout
      assert @config.allow_user_deletion?
      assert @config.magic_link_enabled?
      assert @config.password_complexity_check?
      assert_not @config.sms_auth_enabled?
      assert_not @config.insert_cookie_domain
    end

    test 'customization settings default to what the engine provides' do
      assert_nil @config.layout
      assert_equal "ActionController::Base", @config.parent_controller
      assert_nil @config.after_sign_in_path
      assert_nil @config.after_sign_out_path
    end

    test 'webauthn origin in production comes from HOST' do
      original = ENV["HOST"]
      ENV["HOST"] = "auth.example.com"

      with_rails_env("production") do
        assert_equal "https://auth.example.com", Configuration.new.webauthn_origin
      end
    ensure
      ENV["HOST"] = original
    end

    test 'webauthn_enabled? returns the correct value' do
      @config.webauthn_enabled = true
      assert @config.webauthn_enabled?

      @config.webauthn_enabled = false
      refute @config.webauthn_enabled?

      @config.webauthn_enabled = -> { true }
      assert @config.webauthn_enabled?

      @config.webauthn_enabled = -> { false }
      refute @config.webauthn_enabled?
    end

    test 'pwned_enabled? returns the correct value' do
      @config.pwned_enabled = true
      assert @config.pwned_enabled?

      @config.pwned_enabled = false
      refute @config.pwned_enabled?

      @config.pwned_enabled = -> { true }
      assert @config.pwned_enabled?
    end

    test 'optional features stay off when their gem is not installed' do
      webauthn = Object.send(:remove_const, :WebAuthn)
      pwned = Object.send(:remove_const, :Pwned)

      @config.webauthn_enabled = true
      @config.pwned_enabled = true

      refute @config.webauthn_enabled?
      refute @config.passkey_only?
      refute @config.pwned_enabled?
    ensure
      Object.const_set(:WebAuthn, webauthn)
      Object.const_set(:Pwned, pwned)
    end

    test 'OAuth needs the gem and a provider, so an app that only uses OmniAuth itself is left alone' do
      assert_equal defined?(OmniAuth), @config.oauth_enabled
      assert_empty @config.oauth_providers
      refute @config.oauth_enabled?

      @config.oauth_provider :github, "id", "secret"
      assert @config.oauth_enabled?

      omniauth = Object.send(:remove_const, :OmniAuth)
      refute @config.oauth_enabled?
    ensure
      Object.const_set(:OmniAuth, omniauth) if omniauth
    end

    test 'oauth_enabled? can be turned off, including by a callable' do
      @config.oauth_provider :github, "id", "secret"

      @config.oauth_enabled = false
      refute @config.oauth_enabled?

      @config.oauth_enabled = -> { false }
      refute @config.oauth_enabled?

      @config.oauth_enabled = -> { true }
      assert @config.oauth_enabled?
    end

    test 'oauth_provider keeps what OmniAuth needs and leaves out the label' do
      @config.oauth_provider :github, "id", "secret", scope: "user:email", label: "Work GitHub"
      provider = @config.oauth_providers.first

      assert_equal :github, provider.strategy
      assert_equal %w[id secret], provider.args
      assert_equal({ scope: "user:email" }, provider.options)
      assert_equal "Work GitHub", provider.label
    end

    test 'providers have sensible labels' do
      %w[github google_oauth2 facebook twitter2 some_sso].zip(%w[GitHub Google Facebook X Some\ Sso]).each do |key, label|
        @config.oauth_provider key.to_sym, "id", "secret"

        assert_equal label, @config.oauth_providers.last.label
      end
    end

    test 'the name option decides the key, which is what OmniAuth uses in its paths' do
      @config.oauth_provider :google_oauth2, "id", "secret", name: "google"

      assert_equal "google", @config.oauth_providers.first.key
    end

    test 'adding a provider again replaces it' do
      @config.oauth_provider :github, "old", "old"
      @config.oauth_provider :github, "new", "new"

      assert_equal 1, @config.oauth_providers.size
      assert_equal %w[new new], @config.oauth_providers.first.args
    end

    test 'passkey_only? needs WebAuthn too' do
      @config.passkey_only = true

      @config.webauthn_enabled = false
      refute @config.passkey_only?

      @config.webauthn_enabled = true
      assert @config.passkey_only?
    end
  end
end
