require "test_helper"

module ActionAuth
  class SessionTest < ActiveSupport::TestCase
    def setup
      @user = action_auth_users(:one)
    end

    test "should belong to user" do
      session = @user.sessions.new
      assert_respond_to session, :user
    end

    test "should set user_agent and ip_address before create" do
      Current.user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
      Current.ip_address = "192.168.1.1"

      session = @user.sessions.create

      assert_equal Current.user_agent, session.user_agent
      assert_equal Current.ip_address, session.ip_address
    end
  end
end
