module SignInAsHelper
  def sign_in_as(user)
    session = user.sessions.create
    signed_cookies = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
    signed_cookies.signed[:session_token] = { value: session.id, httponly: true }
    cookies[:session_token] = signed_cookies[:session_token]
    session
  end
end
