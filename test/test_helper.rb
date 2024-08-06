# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require 'simplecov'
SimpleCov.start "rails" do
  add_filter '/test/'
end

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require_relative "../test/support/sign_in_as_helper.rb"
require "rails/test_help"
require 'bcrypt'

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class ActionDispatch::IntegrationTest
  include SignInAsHelper
  def create_user_with_credential(email: 'user@example.com',
                                  password: 'Password123456',
                                  credential_nickname: 'USB Key',
                                  webauthn_credential: nil)
    if webauthn_credential.blank?
      raw_challenge = SecureRandom.random_bytes(32)
      challenge = WebAuthn.configuration.encoder.encode(raw_challenge)
      public_key_credential = WebAuthn::FakeClient.new("http://localhost:3000").create(challenge: challenge)
      webauthn_credential = WebAuthn::Credential.from_create(public_key_credential)
    end

    ActionAuth::User.create!(
      email: email,
      password: password,
      webauthn_credentials: [
        ActionAuth::WebauthnCredential.new(
          external_id: webauthn_credential.id,
          nickname: credential_nickname,
          public_key: webauthn_credential.public_key,
          sign_count: webauthn_credential.sign_count
        )
      ]
    )
  end
end
