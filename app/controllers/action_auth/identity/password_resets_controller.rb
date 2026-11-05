module ActionAuth
  module Identity
    class PasswordResetsController < ApplicationController
      before_action :set_user, only: %i[ edit update ]

      rate_limit to: 5,
        within: 1.minute,
        only: :create,
        name: "password-reset-request-throttle",
        with: -> { redirect_to new_identity_password_reset_path, alert: "Too many requests. Try again later." }

      before_action :validate_new_password, only: :update

      def new
      end

      def edit
      end

      # The response is the same whether or not the account exists, so this form
      # can't be used to find out who has an account.
      def create
        user = ActionAuth::User.find_by(email: string_param(:email), verified: true)
        UserMailer.with(user: user).password_reset.deliver_later if user

        redirect_to sign_in_path, notice: "If that email address has been verified, you'll receive reset instructions shortly."
      end

      def update
        if @user.update(user_params)
          redirect_to sign_in_path, notice: "Your password was reset successfully. Please sign in", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = ActionAuth::User.find_by_token_for!(:password_reset, string_param(:sid))
      rescue StandardError
        redirect_to new_identity_password_reset_path, alert: "That password reset link is invalid"
      end

      def user_params
        params.permit(:password, :password_confirmation)
      end

      def validate_new_password
        reject_unusable_password(@user, :edit)
      end
    end
  end
end
