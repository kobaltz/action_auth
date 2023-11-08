require "test_helper"

module ActionAuth
  class RegistrationsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get new" do
      get sign_in_path
      assert_response :success
    end

    test "should sign up" do
      assert_difference("ActionAuth::User.count") do
        email = "#{SecureRandom.hex}@#{SecureRandom.hex}.com"
        post sign_up_path, params: { email: email, password: "123456789012", password_confirmation: "123456789012" }
      end
      assert_response :redirect
    end
  end
end
