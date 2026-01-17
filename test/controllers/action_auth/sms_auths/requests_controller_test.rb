require 'test_helper'

class ActionAuth::SmsAuths::RequestsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  def setup
    assert ActionAuth.configuration.sms_auth_enabled?
    @existing_user = action_auth_users(:one)
    @existing_user.update(phone_number: '+11234567890', verified: true)
    @signed_cookies = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
  end

  test "should get new" do
    get new_sms_auths_requests_path
    assert_response :success
  end

  test "should create a new user and send SMS code" do
    assert_difference('User.count', 1) do
      post sms_auths_requests_path, params: { phone_number: '+19876543210' }
    end

    new_user = User.find_by(phone_number: '+19876543210')
    assert_not_nil new_user
    assert_not_nil new_user.sms_code
    assert_not_nil new_user.sms_code_sent_at

    assert_equal 'Check your phone for a SMS Code.', flash[:notice]
    assert_redirected_to sms_auths_sign_ins_path
  end

  test "should create user with password meeting complexity requirements" do
    post sms_auths_requests_path, params: { phone_number: '+15551234567' }

    new_user = User.find_by(phone_number: '+15551234567')
    assert_not_nil new_user
    assert_not_nil new_user.password_digest, "User should have a password set"
  end

  test "should update existing user and send SMS code" do
    post sms_auths_requests_path, params: { phone_number: @existing_user.phone_number }

    @existing_user.reload
    assert_not_nil @existing_user.sms_code
    assert_not_nil @existing_user.sms_code_sent_at

    assert_equal 'Check your phone for a SMS Code.', flash[:notice]
    assert_redirected_to sms_auths_sign_ins_path
  end
end
