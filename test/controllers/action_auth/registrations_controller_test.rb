require "test_helper"

module ActionAuth
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get new" do
      get sign_up_path
      assert_response :success
    end

    test "should sign up" do
      assert_difference("ActionAuth::User.count") do
        email = "#{SecureRandom.hex}@#{SecureRandom.hex}.com"
        post sign_up_path, params: { email: email, password: email, password_confirmation: email }
      end
      assert_response :redirect
    end

    test "should not sign up" do
      assert_no_difference("ActionAuth::User.count") do
        email = "#{SecureRandom.hex}@#{SecureRandom.hex}.com"
        post sign_up_path, params: { email: email, password: email, password_confirmation: "123456789012" }
      end
      assert_response :unprocessable_entity
    end

    test "should not sign up with pwned password" do
      assert_no_difference("ActionAuth::User.count") do
        email = "#{SecureRandom.hex}@#{SecureRandom.hex}.com"
        post sign_up_path, params: { email: email, password: "Password1234", password_confirmation: "Password1234" }
      end
      assert_response :unprocessable_entity
    end
  end
end
