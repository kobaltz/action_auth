require 'test_helper'

class ActionAuth::SmsAuths::SignInsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  setup do
    @user = action_auth_users(:one)
    @user.update!(phone_number: '+11234567890')
  end

  # Goes through the real request so the signed phone number cookie gets set.
  def request_code
    post sms_auths_requests_path, params: { phone_number: @user.phone_number }
    @user.reload.sms_code
  end

  test "show renders the form" do
    get sms_auths_sign_ins_path

    assert_response :success
    assert_select "form[action=?]", sms_auths_sign_ins_path
  end

  test "the right code signs in, verifies the user and uses up the code" do
    code = request_code

    assert_difference -> { @user.sessions.count }, 1 do
      post sms_auths_sign_ins_path, params: { sms_code: code }
    end

    assert_redirected_to "/"
    @user.reload
    assert @user.verified
    assert_nil @user.sms_code
    assert_nil @user.sms_code_sent_at
    assert_equal "", cookies["sms_auth_phone_number"]
    assert_signed_in
  end

  test "sends people to the configured path" do
    code = request_code

    with_action_auth_config(after_sign_in_path: "/dashboard") do
      post sms_auths_sign_ins_path, params: { sms_code: code }
    end

    assert_redirected_to "/dashboard"
  end

  test "a code can't be used twice" do
    code = request_code
    post sms_auths_sign_ins_path, params: { sms_code: code }

    cookies.delete("session_token")

    assert_no_difference("ActionAuth::Session.count") do
      post sms_auths_sign_ins_path, params: { sms_code: code }
    end
  end

  test "a wrong code does not sign in" do
    request_code

    assert_no_difference("ActionAuth::Session.count") do
      post sms_auths_sign_ins_path, params: { sms_code: 'wrong_code' }
    end

    assert_equal 'Authentication failed, please try again.', flash[:alert]
    assert_redirected_to sign_in_path
    assert_signed_out
  end

  test "an expired code does not sign in" do
    code = request_code

    travel 6.minutes do
      assert_no_difference("ActionAuth::Session.count") do
        post sms_auths_sign_ins_path, params: { sms_code: code }
      end

      assert_equal 'Authentication failed, please try again.', flash[:alert]
    end
  end

  test "a code does not sign in without the cookie from requesting it" do
    code = request_code
    cookies.delete("sms_auth_phone_number")

    assert_no_difference("ActionAuth::Session.count") do
      post sms_auths_sign_ins_path, params: { sms_code: code }
    end

    assert_redirected_to sign_in_path
  end

  test "one request can't try many codes" do
    code = request_code

    assert_no_difference("ActionAuth::Session.count") do
      post sms_auths_sign_ins_path, params: { sms_code: ["000000", code] }
    end

    assert_redirected_to sign_in_path
    assert_signed_out
  end

  test "a non-string or blank code does not sign in" do
    request_code

    [{ sms_code: { a: "b" } }, { sms_code: "" }, {}].each do |params|
      assert_no_difference("ActionAuth::Session.count", "for #{params.inspect}") do
        post sms_auths_sign_ins_path, params: params
      end
    end
  end

  test "a request with no phone number can't be used to sign in as someone else" do
    victim = action_auth_users(:two)
    assert_nil victim.phone_number

    post sms_auths_requests_path
    # Even if a code somehow existed, nothing ties this client to that account.
    victim.update!(sms_code: "123456", sms_code_sent_at: Time.current)

    assert_no_difference -> { victim.sessions.count } do
      post sms_auths_sign_ins_path, params: { sms_code: "123456" }
    end
    assert_signed_out
  end

  test "an account with a security key still has to use it" do
    user, client = create_user_with_authenticator
    user.update!(phone_number: "+15559998888")

    post sms_auths_requests_path, params: { phone_number: user.phone_number }

    assert_no_difference("ActionAuth::Session.count") do
      post sms_auths_sign_ins_path, params: { sms_code: user.reload.sms_code }
    end
    assert_redirected_to new_webauthn_credential_authentications_url
    assert_signed_out

    get new_webauthn_credential_authentications_url
    post_webauthn webauthn_credential_authentications_url, client.get(challenge: webauthn_options_on_page["challenge"])
    assert_signed_in
  end

  test "guesses from one client are rate limited" do
    request_code

    5.times { post sms_auths_sign_ins_path, params: { sms_code: "000000" } }
    assert_equal 'Authentication failed, please try again.', flash[:alert]

    post sms_auths_sign_ins_path, params: { sms_code: @user.reload.sms_code }

    assert_equal "Too many attempts. Try again later.", flash[:alert]
    assert_signed_out
  end

  test "guesses against one phone number are rate limited across clients" do
    request_code

    5.times do |n|
      post sms_auths_sign_ins_path, params: { sms_code: "000000" }, headers: { "REMOTE_ADDR" => "10.0.0.#{n + 1}" }
    end

    post sms_auths_sign_ins_path, params: { sms_code: @user.reload.sms_code }, headers: { "REMOTE_ADDR" => "10.0.0.99" }

    assert_equal "Too many attempts. Try again later.", flash[:alert]
    assert_signed_out
  end
end
