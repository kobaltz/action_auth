# Run by test/integration/upgrade_test.rb in separate processes, against a real
# database with the schema of an app on 1.8.9 and the latest of that release's
# migrations. An app is in this state whenever it has upgraded the gem but not run
# the new migrations, including for a moment during a normal deploy.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "bcrypt"

ENGINE_MIGRATIONS = File.expand_path("../../db/migrate", __dir__)
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../dummy/db/migrate", __dir__), ENGINE_MIGRATIONS]

class UpgradeSchema
  def self.load_previous_release
    ActiveRecord::Migration.suppress_messages do
      ActiveRecord::Schema[7.2].define(version: 2026_11_05_120000) do
        create_table "users", force: :cascade do |t|
          t.string "email"
          t.string "password_digest"
          t.boolean "verified"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
          t.string "webauthn_id"
          t.string "phone_number"
          t.string "sms_code"
          t.datetime "sms_code_sent_at"
          t.datetime "magic_link_used_at"
          t.index ["email"], name: "index_users_on_email", unique: true
        end

        create_table "sessions", force: :cascade do |t|
          t.integer "user_id", null: false
          t.string "user_agent"
          t.string "ip_address"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
          t.index ["user_id"], name: "index_sessions_on_user_id"
        end

        create_table "webauthn_credentials", force: :cascade do |t|
          t.string "external_id", null: false
          t.string "public_key", null: false
          t.string "nickname", null: false
          t.bigint "sign_count", default: 0, null: false
          t.integer "user_id"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
          t.integer "key_type", limit: 2, default: 0
          t.index ["external_id"], name: "index_webauthn_credentials_on_external_id", unique: true
          t.index ["user_id"], name: "index_webauthn_credentials_on_user_id"
        end

        create_table "posts", force: :cascade do |t|
          t.integer "user_id", null: false
          t.string "title"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
          t.index ["user_id"], name: "index_posts_on_user_id"
        end

        add_foreign_key "posts", "users"
        add_foreign_key "sessions", "users"
        add_foreign_key "webauthn_credentials", "users"
      end
    end
  end

  # Someone who signed up before the upgrade, whose row the migrations have to keep.
  def self.add_existing_user
    ActiveRecord::Base.connection.execute(<<~SQL)
      INSERT INTO users (email, password_digest, verified, created_at, updated_at)
      VALUES ('existing@example.com', '#{BCrypt::Password.create("123456789012", cost: 4)}', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    SQL
  end

  def self.run_new_migrations
    ActiveRecord::Migration.suppress_messages { ActiveRecord::MigrationContext.new(ENGINE_MIGRATIONS).migrate }
    ActionAuth::User.reset_column_information
  end
end

if ENV["UPGRADE_CHECK"] == "migrated"
  UpgradeSchema.load_previous_release
  UpgradeSchema.add_existing_user
  UpgradeSchema.run_new_migrations
  EXISTING_USER_AFTER_MIGRATING = ActionAuth::User.find_by(email: "existing@example.com").attributes
else
  UpgradeSchema.load_previous_release
end

# Otherwise rails/test_help would replace this database with test/dummy/db/schema.rb.
# Set here because loading ActiveRecord::Base, which the above did, resets it.
ActiveRecord.maintain_test_schema = false

require "test_helper"

if ENV["UPGRADE_CHECK"] == "migrated"
  class UpgradeAfterMigratingCheck < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @user = action_auth_users(:one)
      @user.update!(verified: true)
    end

    test "the migrations keep existing accounts, in a usable state" do
      assert_equal 0, EXISTING_USER_AFTER_MIGRATING["failed_sign_in_attempts"]
      assert_nil EXISTING_USER_AFTER_MIGRATING["account_locked_at"]
      assert_nil EXISTING_USER_AFTER_MIGRATING["account_suspended_at"]
    end

    test "lockout starts working" do
      assert_enqueued_emails 1 do
        10.times do
          Rails.cache.clear
          post action_auth.sign_in_path, params: { email: @user.email, password: "not the password" }
        end
      end

      assert @user.reload.account_locked?
    end

    test "suspension starts working" do
      sign_in_as(@user)
      @user.suspend_account!

      assert_signed_out
    end

    test "OAuth starts working" do
      OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(provider: "developer", uid: "1", info: { email: "new@example.com" })

      post action_auth.oauth_request_path("developer")
      follow_redirect!

      assert_signed_in
      assert_equal 1, ActionAuth::User.find_by(email: "new@example.com").connected_accounts.count
    end
  end
else
  class UpgradeBeforeMigratingCheck < ActionDispatch::IntegrationTest
    include ActiveJob::TestHelper

    setup do
      @user = action_auth_users(:one)
      @user.update!(verified: true)
    end

    def sign_in_with(password)
      Rails.cache.clear
      post action_auth.sign_in_path, params: { email: @user.email, password: password }
    end

    test "this really is the old schema" do
      assert_not ActionAuth::User.column_names.include?("account_locked_at")
      assert_not ActionAuth::User.column_names.include?("account_suspended_at")
      assert_not ActionAuth::User.column_names.include?("failed_sign_in_attempts")
      assert_not ActiveRecord::Base.connection.table_exists?("action_auth_connected_accounts")
    end

    test "signing in works" do
      sign_in_with(FIXTURE_PASSWORD)

      assert_redirected_to "/"
      assert_signed_in
    end

    test "wrong passwords answer as they always did, and don't lock anyone out" do
      assert_no_enqueued_emails do
        25.times do
          sign_in_with("not the password")
          assert_equal "That email or password is incorrect", flash[:alert]
        end
      end

      sign_in_with(FIXTURE_PASSWORD)

      assert_signed_in
    end

    test "the log says what to do" do
      logs = StringIO.new
      original = Rails.logger
      Rails.logger = ActiveSupport::Logger.new(logs)

      sign_in_with("not the password")

      assert_match "action_auth:install:migrations", logs.string
    ensure
      Rails.logger = original
    end

    test "existing sessions keep working, on the app's own pages too" do
      sign_in_as(@user)

      get "/"
      assert_response :success

      get action_auth.sessions_path
      assert_response :success
      assert_select "h2", text: "Connected Accounts", count: 0
    end

    test "signing out works" do
      session = sign_in_as(@user)

      delete action_auth.session_path(session)

      assert_signed_out
    end

    test "signing up works" do
      post action_auth.sign_up_path, params: { email: "new@example.com", password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }

      assert_redirected_to action_auth.sign_in_path
      assert ActionAuth::User.exists?(email: "new@example.com")
    end

    test "magic links work" do
      post action_auth.magics_requests_path, params: { email: @user.email }
      assert_enqueued_emails 1

      post action_auth.magics_sign_ins_path, params: { token: @user.generate_token_for(:magic_token) }
      assert_signed_in
    end

    test "a magic link that verifies an account works, with no connected accounts to remove yet" do
      @user.update!(verified: false)

      post action_auth.magics_sign_ins_path, params: { token: @user.generate_token_for(:magic_token) }

      assert_signed_in
      assert @user.reload.verified
      assert_not @user.authenticate_password(FIXTURE_PASSWORD)
    end

    test "verifying an email works, including a wrong password" do
      @user.update!(verified: false)
      sid = @user.generate_token_for(:email_verification)

      get action_auth.identity_email_verification_path(sid: sid)
      assert_response :success

      patch action_auth.identity_email_verification_path, params: { sid: sid, password: "not the password" }
      assert_response :unprocessable_entity

      patch action_auth.identity_email_verification_path, params: { sid: sid, password: FIXTURE_PASSWORD }
      assert_redirected_to action_auth.sign_in_path
      assert @user.reload.verified
    end

    test "a password reset that verifies an account works, with no connected accounts to remove yet" do
      @user.update!(verified: false)

      patch action_auth.identity_password_reset_path,
        params: { sid: @user.generate_token_for(:password_reset), password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }

      assert_redirected_to action_auth.sign_in_path
      assert @user.reload.verified
    end

    test "password resets work" do
      post action_auth.identity_password_reset_path, params: { email: @user.email }
      assert_enqueued_emails 1

      patch action_auth.identity_password_reset_path,
        params: { sid: @user.generate_token_for(:password_reset), password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }

      assert @user.reload.authenticate(STRONG_PASSWORD)
    end

    test "SMS sign in works, including a wrong code" do
      @user.update!(phone_number: "+11234567890")
      post action_auth.sms_auths_requests_path, params: { phone_number: @user.phone_number }
      code = @user.reload.sms_code

      post action_auth.sms_auths_sign_ins_path, params: { sms_code: code == "111111" ? "222222" : "111111" }
      assert_equal "Authentication failed, please try again.", flash[:alert]

      post action_auth.sms_auths_sign_ins_path, params: { sms_code: code }
      assert_signed_in
    end

    test "passkeys work" do
      user, client = create_user_with_authenticator(email: "passkey@example.com")

      get action_auth.new_sessions_passkey_path
      post_webauthn action_auth.sessions_passkeys_path, client.get(challenge: webauthn_options_on_page["challenge"], user_verified: true)

      assert_response :success
      assert_equal 1, user.sessions.count
    end

    test "deleting an account works, with nothing to query in a table that isn't there yet" do
      sign_in_as(@user)

      assert_difference "ActionAuth::User.count", -1 do
        delete action_auth.users_path, params: { password_challenge: FIXTURE_PASSWORD }
      end
    end

    test "suspending fails loudly rather than appearing to work" do
      error = assert_raises(RuntimeError) { @user.suspend_account! }

      assert_match "action_auth:install:migrations", error.message
    end

    test "turning OAuth on without the migration explains itself" do
      OmniAuth.config.mock_auth[:developer] = OmniAuth::AuthHash.new(provider: "developer", uid: "1", info: { email: "new@example.com" })

      post action_auth.oauth_request_path("developer")

      error = assert_raises(RuntimeError) { follow_redirect! }
      assert_match "action_auth:install:migrations", error.message
    end
  end
end
