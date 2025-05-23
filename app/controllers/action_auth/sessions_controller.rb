module ActionAuth
  class SessionsController < ApplicationController
    before_action :set_current_request_details
    before_action :authenticate_user!, only: [:index, :destroy]

    rate_limit to: 5,
      within: 20.seconds,
      only: :create,
      name: "slow-throttle",
      with: -> { redirect_to sign_in_path, alert: "Try again later." }

    def index
      @action_auth_wide = true
      @sessions = Current.user.sessions.order(created_at: :desc)
    end

    def new
    end

    def create
      if user = User.authenticate_by(email: params[:email], password: params[:password])
        if user.second_factor_enabled?
          session[:webauthn_user_id] = user.id
          redirect_to new_webauthn_credential_authentications_path
        else
          return if check_if_email_is_verified(user)
          @session = user.sessions.create
          session_token_hash = { value: @session.id, httponly: true }
          session_token_hash[:secure] = Rails.env.production? if Rails.env.production?
          session_token_hash[:same_site] = :lax unless Rails.env.test?
          session_token_hash[:domain] = :all if ActionAuth.configuration.insert_cookie_domain
          cookies.signed.permanent[:session_token] = session_token_hash
          redirect_to main_app.root_path, notice: "Signed in successfully"
        end
      else
        redirect_to sign_in_path(email_hint: params[:email]), alert: "That email or password is incorrect"
      end
    end

    def destroy
      session = Current.user.sessions.find(params[:id])
      session.destroy
      cookie_options = {}
      cookie_options[:secure] = Rails.env.production? if Rails.env.production?
      cookie_options[:same_site] = :lax unless Rails.env.test?
      cookies.delete(:session_token, cookie_options)
      response.headers["Clear-Site-Data"] = '"cache","storage"'
      redirect_to main_app.root_path, notice: "That session has been logged out"
    end

    private

    def check_if_email_is_verified(user)
      return false unless ActionAuth.configuration.verify_email_on_sign_in
      return false if user.verified?

      redirect_to sign_in_path(email_hint: params[:email]),
        alert: "You must verify your email before you sign in."
    end
  end
end
