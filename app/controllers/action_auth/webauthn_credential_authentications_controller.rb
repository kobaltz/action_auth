class ActionAuth::WebauthnCredentialAuthenticationsController < ApplicationController
  before_action :ensure_user_not_authenticated
  before_action :ensure_login_initiated
  layout "action_auth/application"

  rate_limit to: 5,
    within: 20.seconds,
    only: :create,
    name: "webauthn-throttle",
    with: -> { redirect_to sign_in_path, alert: "Too many attempts. Try again later." }

  def new
    get_options = WebAuthn::Credential.options_for_get(allow: user.webauthn_credentials.pluck(:external_id))
    session[:current_challenge] = get_options.challenge
    @options = get_options
  end

  def create
    webauthn_credential = WebAuthn::Credential.from_get(params)

    credential = user.webauthn_credentials.find_by(external_id: webauthn_credential.id)

    begin
      webauthn_credential.verify(
        session[:current_challenge],
        public_key: credential.public_key,
        sign_count: credential.sign_count
      )

      credential.update!(sign_count: webauthn_credential.sign_count)
      session.delete(:webauthn_user_id)
      session = user.sessions.create
      cookie_options = { value: session.id, httponly: true }
      cookie_options[:secure] = Rails.env.production? if Rails.env.production?
      cookie_options[:same_site] = :lax unless Rails.env.test?
      cookies.signed.permanent[:session_token] = cookie_options
      render json: { status: "ok" }, status: :ok
    rescue WebAuthn::Error => e
      Rails.logger.error "❌ Verification failed: #{e.message}"
      render json: "Verification failed: #{e.message}", status: :unprocessable_entity
    end
  end

  private

  def user
    @user ||= ActionAuth::User.find_by(id: session[:webauthn_user_id])
  end

  def ensure_login_initiated
    return unless session[:webauthn_user_id].blank?
    redirect_to sign_in_path
  end

  def ensure_user_not_authenticated
    return unless current_user
    redirect_to main_app.root_path
  end
end
