module ActionAuth
  class SessionsController < ApplicationController
    before_action :set_current_request_details
    layout "action_auth/application-full-width", only: :index
    def index
      @sessions = Current.user.action_auth_sessions.order(created_at: :desc)
    end

    def new
    end

    def create
      if user = User.authenticate_by(email: params[:email], password: params[:password])
        @session = user.action_auth_sessions.create
        cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
        redirect_to main_app.root_path, notice: "Signed in successfully"
      else
        redirect_to sign_in_path(email_hint: params[:email]), alert: "That email or password is incorrect"
      end
    end

    def destroy
      session = Current.user.action_auth_sessions.find(params[:id])
      session.destroy
      redirect_to(main_app.root_path, notice: "That session has been logged out")
    end
  end
end
