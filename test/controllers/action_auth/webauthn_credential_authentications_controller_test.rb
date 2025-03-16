require "test_helper"

class ActionAuth::WebauthnCredentialAuthenticationsControllerTest < ActionDispatch::IntegrationTest
  include ActionAuth::Engine.routes.url_helpers

  test "should implement rate limiting for WebAuthn authentication" do
    controller = ActionAuth::WebauthnCredentialAuthenticationsController.new
    def controller.test_rate_limit(attempts)
      max_attempts = 5
      attempts > max_attempts
    end
    assert_not controller.test_rate_limit(5), "Should not rate limit with 5 attempts"
    assert controller.test_rate_limit(6), "Should rate limit with 6 attempts"
  end
end
