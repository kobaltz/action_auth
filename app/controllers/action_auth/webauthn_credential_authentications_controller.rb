module ActionAuth
  class WebauthnCredentialAuthenticationsController < ApplicationController
    before_action :ensure_user_not_authenticated
    before_action :ensure_login_initiated

    rate_limit to: 5,
      within: 20.seconds,
      only: :create,
      name: "webauthn-throttle",
      with: -> { render json: "Too many attempts. Try again later.", status: :too_many_requests }

    def new
      get_options = WebAuthn::Credential.options_for_get(allow: user.webauthn_credentials.pluck(:external_id))
      session[:current_challenge] = get_options.challenge
      @options = get_options
    end

    def create
      if verify_webauthn_assertion(user.webauthn_credentials)
        session.delete(:webauthn_user_id)
        start_session_for(user)
        render json: { status: "ok", redirect_url: after_sign_in_path }
      else
        render json: "Verification failed", status: :unprocessable_entity
      end
    end

    private

    def user
      @user ||= ActionAuth::User.find_by(id: session[:webauthn_user_id])
    end

    def ensure_login_initiated
      return if user
      redirect_to sign_in_path
    end

    def ensure_user_not_authenticated
      return unless current_user
      redirect_to after_sign_in_path
    end
  end
end
