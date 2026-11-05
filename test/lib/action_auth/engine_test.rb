require "test_helper"

class ActionAuth::EngineTest < ActiveSupport::TestCase
  test "assets are registered with Sprockets" do
    assert_includes Rails.application.config.assets.precompile, "action_auth_manifest.js"
  end

  test "WebAuthn is configured even if the app never calls configure" do
    ActionAuth.configure_webauthn

    assert_equal ["http://localhost:3000"], WebAuthn.configuration.allowed_origins
    assert_equal ActionAuth.configuration.webauthn_rp_name, WebAuthn.configuration.rp_name
  end

  test "several WebAuthn origins can be allowed" do
    original = WebAuthn.configuration.allowed_origins

    with_action_auth_config(webauthn_origin: ["https://a.example.com", "https://b.example.com"]) do
      ActionAuth.configure_webauthn
      assert_equal ["https://a.example.com", "https://b.example.com"], WebAuthn.configuration.allowed_origins
    end
  ensure
    WebAuthn.configuration.allowed_origins = original
  end

  test "configuring WebAuthn does nothing when it's turned off" do
    original = WebAuthn.configuration.allowed_origins

    with_action_auth_config(webauthn_enabled: false, webauthn_origin: "https://ignored.example.com") do
      ActionAuth.configure_webauthn
      assert_equal original, WebAuthn.configuration.allowed_origins
    end
  end

  test "configure yields the configuration and applies WebAuthn" do
    original = WebAuthn.configuration.allowed_origins
    ActionAuth.configure { |config| config.webauthn_origin = "https://yielded.example.com" }

    assert_equal ["https://yielded.example.com"], WebAuthn.configuration.allowed_origins
  ensure
    ActionAuth.configuration.webauthn_origin = original.first
    WebAuthn.configuration.allowed_origins = original
  end
end
