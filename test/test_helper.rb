# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require_relative "support/coverage"

require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require_relative "../test/support/sign_in_as_helper.rb"
require_relative "../test/support/webauthn_helper.rb"
require "rails/test_help"
require 'bcrypt'

# Load fixtures from the engine
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [File.expand_path("fixtures", __dir__)]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  ActiveSupport::TestCase.fixtures :all
end

class SmsSender
  def self.send_code(phone_number, code)
    true
  end
end

# The suite never calls the real Have I Been Pwned API. Everything reports "not
# pwned" unless a test says otherwise with with_pwned_count or with_pwned_outage.
module FakePwnedApi
  class << self
    attr_accessor :count, :error
  end

  def pwned_count
    raise FakePwnedApi.error if FakePwnedApi.error

    FakePwnedApi.count.to_i
  end
end
Pwned::Password.prepend(FakePwnedApi)

class ActiveSupport::TestCase
  # Matches the digest in test/fixtures/action_auth/users.yml. Hashes directly, so
  # it doesn't have to satisfy the complexity rules.
  FIXTURE_PASSWORD = "123456789012"
  # Satisfies every password rule, for anything that goes through validation.
  STRONG_PASSWORD = "MyV3ry$ecureP@ssw0rd!"

  setup { Rails.cache.clear }

  def with_action_auth_config(**settings)
    config = ActionAuth.configuration
    original = settings.keys.to_h { |name| [name, config.public_send(name)] }
    settings.each { |name, value| config.public_send("#{name}=", value) }
    yield
  ensure
    original.each { |name, value| config.public_send("#{name}=", value) }
  end

  def with_pwned_count(count)
    FakePwnedApi.count = count
    yield
  ensure
    FakePwnedApi.count = nil
  end

  def with_pwned_outage(error = Pwned::Error.new("API unavailable"))
    FakePwnedApi.error = error
    yield
  ensure
    FakePwnedApi.error = nil
  end

  def with_rails_env(name)
    original = Rails.env
    Rails.env = name
    yield
  ensure
    Rails.env = original
  end
end

class ActionDispatch::IntegrationTest
  include SignInAsHelper
  include WebauthnHelper

  def create_user_with_credential(email: 'user@example.com',
                                  password: STRONG_PASSWORD,
                                  credential_nickname: 'USB Key',
                                  webauthn_credential: nil)
    if webauthn_credential.blank?
      public_key_credential = fake_webauthn_client.create(challenge: random_webauthn_challenge)
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
