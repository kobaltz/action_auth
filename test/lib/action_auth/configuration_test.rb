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

    test 'passkey_only? needs WebAuthn too' do
      @config.passkey_only = true

      @config.webauthn_enabled = false
      refute @config.passkey_only?

      @config.webauthn_enabled = true
      assert @config.passkey_only?
    end
  end
end
