require "test_helper"

# An address nobody has proved may not belong to whoever put it on the account. They
# could have signed up with it, or changed their own account to it. When its owner
# first uses a magic link, the account has to become theirs alone.
class AccountPreHijackingTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  VICTIM = "victim@example.com".freeze
  ATTACKER = "attacker@example.com".freeze
  NEW_PASSWORD = "An0ther!Str0ng#Passw0rd".freeze

  setup do
    @attacker = open_session
  end

  def sign_up_with_the_victims_address
    @attacker.post action_auth.sign_up_path,
      params: { email: VICTIM, password: STRONG_PASSWORD, password_confirmation: STRONG_PASSWORD }

    ActionAuth::User.find_by!(email: VICTIM)
  end

  # Needs no settings changed, because the account really was verified until now.
  def move_the_attackers_account_to_the_victims_address
    user = ActionAuth::User.create!(email: ATTACKER, password: STRONG_PASSWORD, verified: true)
    user.connected_accounts.create!(provider: "developer", uid: "the-attackers-account")

    @attacker.post action_auth.sign_in_path, params: { email: ATTACKER, password: STRONG_PASSWORD }
    @attacker.patch action_auth.identity_email_path, params: { email: VICTIM, password_challenge: STRONG_PASSWORD }

    user.reload
    assert_equal VICTIM, user.email
    assert_not user.verified?
    assert attackers_session_works?
    user
  end

  def attackers_session_works?
    @attacker.get action_auth.sessions_path
    @attacker.response.successful?
  end

  def password_signs_in?(password = STRONG_PASSWORD)
    Rails.cache.clear
    browser = open_session
    browser.post action_auth.sign_in_path, params: { email: VICTIM, password: password }
    browser.flash[:notice] == "Signed in successfully"
  end

  def use_magic_link(user)
    Rails.cache.clear
    post action_auth.magics_sign_ins_path, params: { token: user.reload.generate_token_for(:magic_token) }
  end

  test "a password from signing up with the address never starts working" do
    user = sign_up_with_the_victims_address
    assert_not password_signs_in?

    use_magic_link(user)

    assert user.reload.verified
    assert_not password_signs_in?
  end

  test "with verification turned off, the session and password from signing up both stop working" do
    with_action_auth_config(verify_email_on_sign_in: false) do
      user = sign_up_with_the_victims_address
      assert attackers_session_works?
      assert password_signs_in?

      use_magic_link(user)

      assert_not attackers_session_works?
      assert_not password_signs_in?
    end
  end

  test "an account moved to the address loses its session, password and connected provider" do
    user = move_the_attackers_account_to_the_victims_address

    use_magic_link(user)

    assert_signed_in
    assert_not attackers_session_works?
    assert_not password_signs_in?
    assert_empty user.connected_accounts.reload
  end

  test "signing in through that provider afterwards doesn't reach the account" do
    user = move_the_attackers_account_to_the_victims_address
    use_magic_link(user)
    OmniAuth.config.mock_auth[:developer] =
      OmniAuth::AuthHash.new(provider: "developer", uid: "the-attackers-account", info: {})

    assert_no_difference -> { user.sessions.count } do
      @attacker.post action_auth.oauth_request_path("developer")
      @attacker.follow_redirect!
    end
  end

  test "a reset link sent before the account moved stops working" do
    user = move_the_attackers_account_to_the_victims_address
    reset_link = user.generate_token_for(:password_reset)

    use_magic_link(user)

    get action_auth.edit_identity_password_reset_path(sid: reset_link)
    assert_redirected_to action_auth.new_identity_password_reset_path
  end

  test "this browser's own earlier session doesn't outlive the proof either" do
    user = ActionAuth::User.create!(email: VICTIM, password: STRONG_PASSWORD, verified: false)
    earlier = sign_in_as(user)

    use_magic_link(user)

    assert_not user.sessions.exists?(earlier.id)
    assert_signed_in
  end

  test "the confirmation page says what signing in will replace, before anything happens" do
    user = sign_up_with_the_victims_address

    get action_auth.magics_sign_ins_path(token: user.generate_token_for(:magic_token))

    assert_select "p", /replace any password set on this account/
    assert user.reload.authenticate_password(STRONG_PASSWORD)
  end

  test "the confirmation page doesn't say that to an account that's already verified" do
    user = ActionAuth::User.create!(email: VICTIM, password: STRONG_PASSWORD, verified: true)

    get action_auth.magics_sign_ins_path(token: user.generate_token_for(:magic_token))

    assert_select "p", text: /replace any password/, count: 0
  end

  test "the owner is signed in, and can choose a new password" do
    user = sign_up_with_the_victims_address

    use_magic_link(user)

    assert_redirected_to "/"
    assert_signed_in

    assert_enqueued_emails 1 do
      post action_auth.identity_password_reset_path, params: { email: VICTIM }
    end

    patch action_auth.identity_password_reset_path, params: {
      sid: user.reload.generate_token_for(:password_reset),
      password: NEW_PASSWORD,
      password_confirmation: NEW_PASSWORD
    }

    assert password_signs_in?(NEW_PASSWORD)
    assert_not password_signs_in?(STRONG_PASSWORD)
  end

  test "someone signing up through a magic link gets in as usual" do
    post action_auth.magics_requests_path, params: { email: VICTIM }

    use_magic_link(ActionAuth::User.find_by!(email: VICTIM))

    assert_redirected_to "/"
    assert_signed_in
  end

  test "an account that's already verified keeps its password, sessions and providers" do
    user = ActionAuth::User.create!(email: VICTIM, password: STRONG_PASSWORD, verified: true)
    connected_account = user.connected_accounts.create!(provider: "developer", uid: "12345")
    other_device = user.sessions.create!

    use_magic_link(user)

    assert user.sessions.exists?(other_device.id)
    assert user.connected_accounts.exists?(connected_account.id)
    assert password_signs_in?
  end

  test "only the first proof replaces anything" do
    user = sign_up_with_the_victims_address
    use_magic_link(user)
    user.reload.update!(password: NEW_PASSWORD)

    use_magic_link(user)

    assert_signed_in
    assert password_signs_in?(NEW_PASSWORD)
  end

  test "a security key stays and is still asked for, since an inbox alone mustn't remove a second factor" do
    user, = create_user_with_authenticator(email: VICTIM, verified: false)

    assert_no_difference -> { user.webauthn_credentials.count } do
      use_magic_link(user)
    end

    assert_redirected_to action_auth.new_webauthn_credential_authentications_path
    assert_signed_out
    assert_not user.reload.authenticate_password(STRONG_PASSWORD)
  end
end
