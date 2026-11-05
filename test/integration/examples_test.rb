require "test_helper"

# examples/ isn't loaded by the engine, so nothing else notices when it goes stale.
class ExamplesTest < ActionDispatch::IntegrationTest
  EXAMPLES = File.expand_path("../../examples", __dir__)

  # The examples use images only a real app has.
  module WithoutAppImages
    def image_tag(*)
      ""
    end
  end

  setup do
    @original_view_paths = ActionAuth::ApplicationController.view_paths
    ActionAuth::ApplicationController.prepend_view_path(EXAMPLES)
    ActionAuth::ApplicationController.helper(WithoutAppImages)
    @user = action_auth_users(:one)
    @user.update!(verified: true)
  end

  teardown { ActionAuth::ApplicationController.view_paths = @original_view_paths }

  test "every example renders for a signed out visitor" do
    [
      action_auth.sign_in_path,
      action_auth.sign_up_path,
      action_auth.new_identity_password_reset_path,
      action_auth.edit_identity_email_path,
      action_auth.new_magics_requests_path
    ].each do |path|
      get path

      assert_response :success, "for #{path}"
      assert_select "main", { minimum: 1 }, "#{path} should come from examples/"
    end
  end

  test "every example renders for a signed in user" do
    sign_in_as(@user)

    [action_auth.sessions_path, action_auth.edit_identity_email_path, action_auth.new_webauthn_credential_path].each do |path|
      get path

      assert_response :success, "for #{path}"
    end
  end

  test "the management example lists security keys" do
    user, = create_user_with_authenticator
    sign_in_as(user)

    get action_auth.sessions_path

    assert_response :success
    assert_select "td", "USB Key"
  end

  test "the second factor example renders mid sign in" do
    user, = create_user_with_authenticator
    post action_auth.sign_in_path, params: { email: user.email, password: STRONG_PASSWORD }

    follow_redirect!

    assert_response :success
    assert webauthn_options_on_page["challenge"].present?
  end

  test "the change email example can actually change an email" do
    sign_in_as(@user)
    get action_auth.edit_identity_email_path

    assert_select "input[name=password_challenge]"

    patch action_auth.identity_email_path, params: { email: "new@example.com", password_challenge: FIXTURE_PASSWORD }

    assert_equal "new@example.com", @user.reload.email
  end

  test "turning features off doesn't break the examples" do
    with_action_auth_config(magic_link_enabled: false, sms_auth_enabled: false, passkey_only: false) do
      get action_auth.sign_in_path

      assert_response :success
      assert_select "a", text: "Magic Link", count: 0
    end
  end
end
