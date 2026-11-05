require "test_helper"

module ActionAuth
  class Magics::RequestsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    test "should get new" do
      get new_magics_requests_path
      assert_response :success
    end

    test "should create user and send magic link" do
      assert_difference('User.count', 1) do
        post magics_requests_url, params: { email: 'newuser@example.com' }
      end

      assert_enqueued_emails 1
      assert_redirected_to sign_in_path
    end

    test "creates users with a password that passes every password rule" do
      post magics_requests_url, params: { email: 'complexpassword@example.com' }

      assert_redirected_to sign_in_path
      assert User.find_by(email: 'complexpassword@example.com').password_digest.present?
    end

    test "should send magic link to existing user" do
      existing_user = action_auth_users(:one)

      assert_no_difference('User.count') do
        post magics_requests_url, params: { email: existing_user.email }
      end

      assert_enqueued_emails 1
      assert_redirected_to sign_in_path
    end

    test "the response is the same for new and existing users" do
      post magics_requests_url, params: { email: action_auth_users(:one).email }
      existing = flash[:notice]

      post magics_requests_url, params: { email: "brand-new@example.com" }

      assert_equal existing, flash[:notice]
    end

    test "invalid emails show the form again with the problem" do
      ["", "not-an-email", ["a@b.co"], { a: "b" }].each do |email|
        Rails.cache.clear

        assert_no_difference('User.count', "for #{email.inspect}") do
          post magics_requests_url, params: { email: email }
        end

        assert_response :unprocessable_entity
        assert_select "form[action=?]", magics_requests_path
        assert_select "[role=alert]", /Email/
      end
    end

    test "a missing email shows the form again" do
      post magics_requests_url

      assert_response :unprocessable_entity
      assert_select "form[action=?]", magics_requests_path
    end

    test "requests are rate limited" do
      5.times { post magics_requests_url, params: { email: action_auth_users(:one).email } }
      assert_enqueued_emails 5

      post magics_requests_url, params: { email: action_auth_users(:one).email }

      assert_redirected_to new_magics_requests_path
      assert_equal "Too many requests. Try again later.", flash[:alert]
      assert_enqueued_emails 5
    end

    test "an app that hasn't run the new migration finds out right away, not from a failed job" do
      columns = User.column_names - ["magic_link_used_at"]
      User.singleton_class.define_method(:column_names) { columns }

      error = assert_raises(RuntimeError) do
        post magics_requests_url, params: { email: action_auth_users(:one).email }
      end

      assert_match "bin/rails action_auth:install:migrations db:migrate", error.message
      assert_enqueued_emails 0
    ensure
      User.singleton_class.remove_method(:column_names)
    end
  end
end
