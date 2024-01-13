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
    end

    test 'should allow reading and writing for webauthn_enabled' do
      @config.webauthn_enabled = false
      assert_equal false, @config.webauthn_enabled
    end

    test 'should allow reading and writing for webauthn_origin' do
      @config.webauthn_origin = 'http://example.com'
      assert_equal 'http://example.com', @config.webauthn_origin
    end

    test 'should allow reading and writing for webauthn_rp_name' do
      @config.webauthn_rp_name = 'MyAppName'
      assert_equal 'MyAppName', @config.webauthn_rp_name
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
  end
end
