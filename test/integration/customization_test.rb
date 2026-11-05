require "test_helper"

class CustomizationTest < ActionDispatch::IntegrationTest
  HOST_VIEWS = File.expand_path("../fixtures/host_views", __dir__)

  setup do
    @user = action_auth_users(:one)
    @user.update!(verified: true)
  end

  # Every screen a signed out visitor can reach
  def public_screens
    [
      action_auth.sign_in_path,
      action_auth.sign_up_path,
      action_auth.new_identity_password_reset_path,
      action_auth.edit_identity_email_path,
      action_auth.new_magics_requests_path,
      action_auth.new_sms_auths_requests_path,
      action_auth.sms_auths_sign_ins_path,
      action_auth.new_sessions_passkey_path
    ]
  end

  def with_host_views
    original = ActionAuth::ApplicationController.view_paths
    ActionAuth::ApplicationController.prepend_view_path(HOST_VIEWS)
    yield
  ensure
    ActionAuth::ApplicationController.view_paths = original
  end

  test "the engine's own layout is the default" do
    get action_auth.sign_in_path

    assert_select "title", "Action Auth"
    assert_select "link[href*=?]", "action_auth/application"
  end

  test "a custom view can set the title in the engine's layout" do
    with_host_views do
      get action_auth.sign_in_path
    end

    assert_select "title", "Sign in to Host App"
  end

  test "config.layout renders every public screen in the app's layout" do
    with_action_auth_config(layout: "application") do
      public_screens.each do |path|
        get path

        assert_response :success, "for #{path}"
        assert_select "title", { text: "Dummy" }, "for #{path}"
        assert_select "a[href=?]", "/", { text: "Home" }, "for #{path}"
      end
    end
  end

  test "config.layout works for signed in screens" do
    sign_in_as(@user)

    with_action_auth_config(layout: "application") do
      [
        action_auth.sessions_path,
        action_auth.edit_password_path,
        action_auth.edit_identity_email_path,
        action_auth.new_webauthn_credential_path
      ].each do |path|
        get path

        assert_response :success, "for #{path}"
        assert_select "title", { text: "Dummy" }, "for #{path}"
        assert_select "a[href=?]", action_auth.sessions_path, { text: "Sessions" }, "for #{path}"
      end
    end
  end

  test "an app's route helpers work in engine-rendered views" do
    with_action_auth_config(layout: "application") do
      get action_auth.sign_in_path
    end

    view = @controller.view_context
    assert_equal "/", view.root_path
    assert_equal "/posts", view.posts_path
    assert_equal "http://www.example.com/posts", view.posts_url
    assert view.respond_to?(:posts_path)
    assert_not view.respond_to?(:not_a_route_path)
    assert_raises(NoMethodError) { view.not_a_route_path }
    assert_raises(NoMethodError) { view.not_a_helper }
  end

  test "the engine's routes win when an app defines the same name" do
    get action_auth.sign_in_path

    assert_equal "/action_auth/sign_in", @controller.view_context.sign_in_path
  end

  test "an app can override a single view" do
    with_host_views do
      get action_auth.sign_in_path
    end

    assert_select "h1#custom-sign-in", "Welcome back to Host App"
  end

  test "an app can override a partial used by the engine's views" do
    with_host_views do
      get action_auth.sign_up_path
    end

    assert_select "nav#custom-links", /Sign In/
    assert_select "h1", "Sign up"
  end

  test "action_auth_links only lists what's turned on" do
    with_action_auth_config(
      magic_link_enabled: false, sms_auth_enabled: false, passkey_only: false, verify_email_on_sign_in: false
    ) do
      get action_auth.sign_up_path

      assert_select ".action-auth--links a", 2
      assert_select ".action-auth--links a", "Sign In"
      assert_select ".action-auth--links a", "Reset Password"
    end
  end

  test "the Verify Email link doesn't appear on the screen it goes to" do
    get action_auth.edit_identity_email_path
    assert_select ".action-auth--links a", text: "Verify Email", count: 0

    get action_auth.sign_in_path
    assert_select ".action-auth--links a[href=?]", action_auth.edit_identity_email_path, text: "Verify Email"
  end

  test "action_auth_links leaves out the current page" do
    get action_auth.sign_in_path
    assert_select ".action-auth--links a", text: "Sign In", count: 0
    assert_select ".action-auth--links a", "Sign Up"

    get action_auth.sign_up_path
    assert_select ".action-auth--links a", text: "Sign Up", count: 0
    assert_select ".action-auth--links a", "Sign In"
  end

  test "screens where people type passwords load no third-party JavaScript" do
    [action_auth.sign_in_path, action_auth.sign_up_path, action_auth.new_magics_requests_path].each do |path|
      get path

      assert_select "script[src*=?]", "action_auth/application", { count: 0 }, "for #{path}"
    end

    sign_in_as(@user)
    [action_auth.edit_password_path, action_auth.edit_identity_email_path].each do |path|
      get path

      assert_select "script[src*=?]", "action_auth/application", { count: 0 }, "for #{path}"
    end
  end

  test "screens that use WebAuthn bring what they need, whatever the layout" do
    user, = create_user_with_authenticator

    [nil, "application", false].each do |layout|
      reset!
      with_action_auth_config(layout: layout) do
        get action_auth.new_sessions_passkey_path
        assert_webauthn_page

        post action_auth.sign_in_path, params: { email: user.email, password: STRONG_PASSWORD }
        follow_redirect!
        assert_webauthn_page

        sign_in_as(user)
        get action_auth.new_webauthn_credential_path
        assert_webauthn_page
      end
      Rails.cache.clear
    end
  end

  test "the default layout doesn't repeat what WebAuthn views already include" do
    get action_auth.new_sessions_passkey_path

    assert_select "script[src*=?]", "action_auth/application", 1
    assert_select "meta[name=webauthn_auth_url]", 1
  end

  test "a WebAuthn view copied from an older version still gets its scripts" do
    original = ActionAuth::ApplicationController.view_paths
    ActionAuth::ApplicationController.prepend_view_path(File.expand_path("../fixtures/old_host_views", __dir__))

    get action_auth.new_sessions_passkey_path

    assert_response :success
    assert_select "h2", "Old copied view"
    assert_select "script[src*=?]", "action_auth/application", 1
    assert_select "meta[name=webauthn_auth_url]", 1
  ensure
    ActionAuth::ApplicationController.view_paths = original
  end

  test "an app can give one group of screens its own layout by naming it after them" do
    with_host_layouts do
      get action_auth.sign_in_path
      assert_select "title", "Just for sessions"

      get action_auth.sign_up_path
      assert_select "title", "Action Auth"
    end
  end

  test "the management screen shows each section and honors the settings" do
    sign_in_as(@user)
    get action_auth.sessions_path

    assert_select "h2", "Sessions"
    assert_select "h2", "Enable Two-Factor Authentication"
    assert_select "h2", "Account"
    assert_select "a[href=?]", action_auth.edit_identity_email_path
    assert_select "a[href=?]", action_auth.edit_password_path
    assert_select "form[action=?]", action_auth.users_path

    with_action_auth_config(allow_user_deletion: false, webauthn_enabled: false) do
      get action_auth.sessions_path

      assert_select "h2", text: "Enable Two-Factor Authentication", count: 0
      assert_select "form[action=?]", action_auth.users_path, count: 0
    end
  end

  test "the management screen lists existing security keys" do
    user, = create_user_with_authenticator
    sign_in_as(user)

    get action_auth.sessions_path

    assert_select "h2", "Your Security Keys"
    assert_select "tr#webauthn_credential_#{user.webauthn_credentials.first.id}", /USB Key/
  end

  test "the back link uses the configured path" do
    sign_in_as(@user)

    with_action_auth_config(after_sign_in_path: "/dashboard") do
      get action_auth.sessions_path
    end

    assert_select "a[href=?]", "/dashboard", text: "back to app"
  end

  test "a Proc for a path runs in the controller, so it can use routes" do
    with_action_auth_config(after_sign_in_path: -> { main_app.posts_path }) do
      post action_auth.sign_in_path, params: { email: @user.email, password: FIXTURE_PASSWORD }
    end

    assert_redirected_to "/posts"
  end

  test "flash messages appear exactly once in the engine's layout" do
    assert_failed_sign_in_message_appears_once(layout: nil)
  end

  test "flash messages appear in an app's layout that doesn't display flash" do
    assert_failed_sign_in_message_appears_once(layout: "application")
  end

  test "flash messages aren't repeated by an app's layout that displays flash too" do
    with_host_layouts do
      assert_failed_sign_in_message_appears_once(layout: "with_flash")
    end
  end

  test "an app can use its layout's flash by emptying the partial" do
    with_host_views do
      with_host_layouts do
        with_action_auth_config(layout: "with_flash") do
          post action_auth.sign_in_path, params: { email: @user.email, password: "SecretWrong1*3" }
          follow_redirect!

          assert_select "#layout-alert", "That email or password is incorrect"
        end
      end
    end
  end

  test "every screen shows flash messages" do
    public_screens.each do |path|
      post action_auth.sign_in_path, params: { email: @user.email, password: "SecretWrong1*3" }
      Rails.cache.clear
      get path

      assert_select "[role=alert]", { text: "That email or password is incorrect" }, "for #{path}"
    end

    user, = create_user_with_authenticator
    sign_in_as(user)
    [action_auth.sessions_path, action_auth.edit_password_path, action_auth.new_webauthn_credential_path].each do |path|
      post action_auth.sign_in_path, params: { email: @user.email, password: "SecretWrong1*3" }
      Rails.cache.clear
      get path

      assert_select "[role=alert]", { text: "That email or password is incorrect" }, "for #{path}"
    end
  end

  test "empty flash leaves no empty elements behind" do
    get action_auth.sign_in_path

    assert_select ".action-auth--notice", 0
    assert_select ".action-auth--alert", 0
  end

  private

  def with_host_layouts
    original = ActionAuth::ApplicationController.view_paths
    ActionAuth::ApplicationController.prepend_view_path(File.expand_path("../fixtures/host_layouts", __dir__))
    yield
  ensure
    ActionAuth::ApplicationController.view_paths = original
  end

  def assert_failed_sign_in_message_appears_once(layout:)
    with_action_auth_config(layout: layout) do
      post action_auth.sign_in_path, params: { email: @user.email, password: "SecretWrong1*3" }
      follow_redirect!
    end

    assert_equal 1, response.body.scan("That email or password is incorrect").size
  end

  def assert_webauthn_page
    assert_response :success
    assert_select "meta[name=webauthn_auth_url]"
    assert_select "meta[name=webauthn_cred_url]"
    assert_select "meta[name=webauthn_redirect_url]"
    assert_select "script[src*=?]", "action_auth/application"
    assert_select "#webauthn_error"
  end
end
