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
end
