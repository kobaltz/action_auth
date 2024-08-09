module ActionAuth
  class Magics::SignInsController < ApplicationController
    def show
      user = ActionAuth::User.find_by_token_for(:magic_token, params[:token])
      if user
        @session = user.sessions.create
        cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
        user.update(verified: true)
        redirect_to main_app.root_path, notice: "Signed In"
      else
        redirect_to sign_in_path, alert: "Authentication failed, please try again."
      end
    end
  end
end
