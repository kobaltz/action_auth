require 'test_helper'

class ActionAuth::SmsAuths::RequestsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  class RecordingSender
    class << self
      attr_accessor :sent

      def send_code(phone_number, code)
        (self.sent ||= []) << [phone_number, code]
      end
    end
  end

  setup do
    assert ActionAuth.configuration.sms_auth_enabled?
    RecordingSender.sent = []
    @existing_user = action_auth_users(:one)
    @existing_user.update!(phone_number: '+11234567890', verified: true)
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
    assert new_user.sms_code.present?
    assert new_user.sms_code_sent_at.present?
    assert_not new_user.verified

    assert_equal 'Check your phone for a SMS Code.', flash[:notice]
    assert_redirected_to sms_auths_sign_ins_path
  end

  test "should update existing user and send SMS code" do
    assert_no_difference('User.count') do
      post sms_auths_requests_path, params: { phone_number: @existing_user.phone_number }
    end

    assert @existing_user.reload.sms_code.present?
    assert_redirected_to sms_auths_sign_ins_path
  end

  test "phone numbers are matched after normalizing" do
    assert_no_difference('User.count') do
      post sms_auths_requests_path, params: { phone_number: '+1 (123) 456-7890' }
    end
  end

  test "sends the same six digit code it stored" do
    with_action_auth_config(sms_send_class: RecordingSender) do
      post sms_auths_requests_path, params: { phone_number: @existing_user.phone_number }
    end

    phone_number, code = RecordingSender.sent.first
    assert_equal @existing_user.phone_number, phone_number
    assert_equal @existing_user.reload.sms_code, code.to_s
    assert_match(/\A[1-9]\d{5}\z/, code.to_s)
  end

  test "a missing sender is logged and doesn't crash" do
    with_action_auth_config(sms_send_class: nil) do
      post sms_auths_requests_path, params: { phone_number: @existing_user.phone_number }
    end

    assert_redirected_to sms_auths_sign_ins_path
  end

  test "no phone number never selects an existing account" do
    victim = action_auth_users(:two)
    assert_nil victim.phone_number

    assert_no_difference('User.count') do
      post sms_auths_requests_path
    end

    assert_response :unprocessable_entity
    assert_nil victim.reload.sms_code
    assert_nil cookies["sms_auth_phone_number"]
  end

  test "invalid phone numbers show the form again with the problem" do
    ['', 'abc', '555', ['+15550001111'], { a: "b" }].each do |phone_number|
      Rails.cache.clear

      assert_no_difference('User.count', "for #{phone_number.inspect}") do
        post sms_auths_requests_path, params: { phone_number: phone_number }
      end

      assert_response :unprocessable_entity
      assert_select "form[action=?]", sms_auths_requests_path
      assert_select "[role=alert]", /Phone number/
    end
  end

  test "requests from one client are rate limited across phone numbers" do
    with_action_auth_config(sms_send_class: RecordingSender) do
      3.times { |n| post sms_auths_requests_path, params: { phone_number: "+1555000000#{n}" } }
      assert_equal 3, RecordingSender.sent.size

      post sms_auths_requests_path, params: { phone_number: "+15550000009" }

      assert_redirected_to new_sms_auths_requests_path
      assert_equal "Too many requests. Try again later.", flash[:alert]
      assert_equal 3, RecordingSender.sent.size
    end
  end

  test "reformatting a phone number doesn't get around the limit" do
    with_action_auth_config(sms_send_class: RecordingSender) do
      ["+15550001111", "+1 555 000 1111", "+1 (555) 000-1111", "+1.555.000.1111"].each_with_index do |number, n|
        post sms_auths_requests_path, params: { phone_number: number },
          headers: { "REMOTE_ADDR" => "10.0.0.#{n + 1}" }
      end

      assert_equal 3, RecordingSender.sent.size
    end
  end

  test "one phone number can't be texted repeatedly from many clients" do
    with_action_auth_config(sms_send_class: RecordingSender) do
      4.times do |n|
        post sms_auths_requests_path, params: { phone_number: @existing_user.phone_number },
          headers: { "REMOTE_ADDR" => "10.0.0.#{n + 1}" }
      end

      assert_equal 3, RecordingSender.sent.size
      assert_equal "Too many requests. Try again later.", flash[:alert]
    end
  end
end
