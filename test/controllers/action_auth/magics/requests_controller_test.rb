require "test_helper"

module ActionAuth
  class Magics::RequestsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get new" do
      get new_magics_requests_path
      assert_response :success
    end

    # Test the 'create' action
    test "should create user and send magic link" do
      assert_difference('User.count', 1) do
        post magics_requests_url, params: { email: 'newuser@example.com' }
      end

      user = User.find_by(email: 'newuser@example.com')
      assert_not_nil user
      assert_enqueued_emails 1
      assert_redirected_to sign_in_path
    end

    test "should send magic link to existing user" do
      existing_user = action_auth_users(:one) # assuming you have a fixture for this
      assert_no_difference('User.count') do
        post magics_requests_url, params: { email: existing_user.email }
      end

      assert_enqueued_emails 1
      assert_redirected_to sign_in_path
    end

    test "should not create user with invalid email" do
      assert_no_difference('User.count') do
        post magics_requests_url, params: { email: '' }
      end

      assert_response :unprocessable_entity
    end

  end
end
