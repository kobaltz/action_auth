module SignInAsHelper
  def sign_in_as(user)
    session = user.sessions.create
    signed_cookies = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    signed_cookies.signed[:session_token] = { value: session.id, httponly: true }
    cookies[:session_token] = signed_cookies[:session_token]
    session
  end

  def assert_signed_in(message = "expected to be signed in")
    get action_auth.sessions_path
    assert_response :success, message
  end

  def assert_signed_out(message = "expected to be signed out")
    get action_auth.sessions_path
    assert_redirected_to action_auth.sign_in_path, message
  end

  # The Set-Cookie line for one cookie, as lowercase attributes with the value removed.
  def set_cookie_attributes(name = "session_token")
    header = Array(response.headers["Set-Cookie"]).flat_map { |line| line.split("\n") }
      .find { |line| line.start_with?("#{name}=") }
    assert header, "expected a Set-Cookie header for #{name}"

    header.split("; ").drop(1).map(&:downcase)
  end
end
