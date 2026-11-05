require 'test_helper'

class MockController < ActionController::Base
  include ActionAuth::Controllers::Helpers
end

class ActionAuth::Controllers::HelpersTest < ActionDispatch::IntegrationTest
  setup do
    @controller = MockController.new
    @session = action_auth_sessions(:one)
    @user = action_auth_users(:one)
    @controller.request = ActionController::TestRequest.create(@controller.class)
  end

  test "current_user should return the current user" do
    ActionAuth::Current.instance.session = @session
    assert_equal @user, @controller.current_user
  end

  test "current_session should return the current session" do
    ActionAuth::Current.session = @session
    assert_equal @session, @controller.current_session
  end

  test "user_signed_in? should return true when user is present" do
    ActionAuth::Current.instance.session = @session
    assert @controller.user_signed_in?
  end

  test "user_signed_in? should return false when no user is present" do
    ActionAuth::Current.instance.session = nil
    refute @controller.user_signed_in?
  end

  test "action_auth_controller? tells the app's controllers from the engine's" do
    refute @controller.action_auth_controller?
    assert ActionAuth::SessionsController.new.send(:action_auth_controller?)
  end

  test "the session cookie is secure in production and on https" do
    assert_not @controller.send(:action_auth_session_cookie_options).key?(:secure)

    with_rails_env("production") do
      assert @controller.send(:action_auth_session_cookie_options)[:secure]
    end

    @controller.request.headers["HTTPS"] = "on"
    assert @controller.send(:action_auth_session_cookie_options)[:secure]
  end

  test "a changed IP address or user agent is logged but keeps the session" do
    user = action_auth_users(:one)
    sign_in_as(user).update!(ip_address: "203.0.113.5", user_agent: "Old Browser")

    assert_signed_in
  end
end

class ActionAuth::Routing::HelpersTest < ActiveSupport::TestCase
  setup do
    controller = WelcomeController.new
    controller.request = ActionController::TestRequest.create(controller.class)
    @view = controller.view_context
    @controller = controller
  end

  test "the route helpers the README lists work from a host view" do
    assert_equal "/action_auth/sessions", @view.user_sessions_path
    assert_equal "/action_auth/sessions/5", @view.user_session_path(5)
    assert_equal "/action_auth/sign_in", @view.new_user_session_path
    assert_equal "/action_auth/sign_up", @view.new_user_registration_path
    assert_equal "/action_auth/password/edit", @view.edit_user_password_path
    assert_equal "/action_auth/password", @view.user_password_path
  end

  test "the older password helpers still work from a host controller" do
    assert_equal "/action_auth/password/edit", @controller.edit_password_path
    assert_equal "/action_auth/password", @controller.password_path
  end
end
