require 'test_helper'

class ActionAuth::SmsAuths::SignInsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  def setup
    @user = action_auth_users(:one)
    @user.update(phone_number: '1234567890', sms_code: '123456', sms_code_sent_at: 2.minutes.ago)
    @signed_cookies = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
  end

  test "should show user for valid phone number" do
    get sms_auths_sign_ins_path, params: { phone_number: @user.phone_number }
    assert_response :success
  end

  test "should not find user for invalid phone number" do
    get sms_auths_sign_ins_path, params: { phone_number: '9876543210' }
    assert_response :success
  end

  test "should sign in user with correct SMS code" do
    @signed_cookies.signed[:sms_auth_phone_number] = @user.phone_number
    assert_not_nil @user.sms_code
    assert_not_nil @user.sms_code_sent_at
    post sms_auths_sign_ins_path, params: { sms_code: @user.sms_code }

    @user.reload
    assert_nil @user.sms_code
    assert_nil @user.sms_code_sent_at

  end

  test "should fail to sign in with incorrect SMS code" do
    @signed_cookies.signed[:sms_auth_phone_number] = @user.phone_number

    post sms_auths_sign_ins_path, params: { sms_code: 'wrong_code' }

    assert_equal 'Authentication failed, please try again.', flash[:alert]
    assert_redirected_to sign_in_path
    assert_nil @signed_cookies.signed[:session_token]
  end

  test "should fail to sign in with expired SMS code" do
    @user.update(sms_code_sent_at: 10.minutes.ago)
    @signed_cookies.signed[:sms_auth_phone_number] = @user.phone_number

    post sms_auths_sign_ins_path, params: { sms_code: @user.sms_code }

    assert_equal 'Authentication failed, please try again.', flash[:alert]
    assert_redirected_to sign_in_path
    assert_nil @signed_cookies.signed[:session_token]
  end

  test "should redirect to sign in path if phone number is not in cookies" do
    post sms_auths_sign_ins_path, params: { sms_code: @user.sms_code }

    assert_equal 'Authentication failed, please try again.', flash[:alert]
    assert_redirected_to sign_in_path
  end
end
