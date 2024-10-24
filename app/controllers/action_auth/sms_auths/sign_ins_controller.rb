module ActionAuth
  class SmsAuths::SignInsController < ApplicationController
    def show
      @user = ActionAuth::User.find_by(phone_number: params[:phone_number])
    end

    def create
      user = ActionAuth::User.find_by(
        phone_number: cookies.signed[:sms_auth_phone_number],
        sms_code: params[:sms_code],
        sms_code_sent_at: 5.minutes.ago..Time.current
      )
      if user
        @session = user.sessions.create
        cookies.signed.permanent[:session_token] = { value: @session.id, httponly: true }
        user.update(
          verified: true,
          sms_code: nil,
          sms_code_sent_at: nil
        )
        redirect_to main_app.root_path, notice: "Signed In"
      else
        redirect_to sign_in_path, alert: "Authentication failed, please try again."
      end
    end
  end
end
