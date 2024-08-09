module ActionAuth
  class UserMailer < ApplicationMailer
    def password_reset
      @user = params[:user]
      @signed_id = @user.generate_token_for(:password_reset)

      mail to: @user.email, subject: "Reset your password"
    end

    def email_verification
      @user = params[:user]
      @signed_id = @user.generate_token_for(:email_verification)

      mail to: @user.email, subject: "Verify your email"
    end

    def magic_link
      @user = params[:user]
      @signed_id = @user.generate_token_for(:magic_token)

      mail to: @user.email, subject: "Sign in to your account"
    end
  end
end
