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
        user = ActionAuth::User.find_by(email: string_param(:email))
        UserMailer.with(user: user).password_reset.deliver_later if user && !user.account_suspended?

        redirect_to sign_in_path, notice: "If there's an account with that email address, you'll receive reset instructions shortly."
      end

      def update
        if @user.reset_password_from_emailed_link(user_params)
          redirect_to sign_in_path, notice: "Your password was reset successfully. Please sign in", status: :see_other
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = ActionAuth::User.find_by_token_for!(:password_reset, string_param(:sid))
        redirect_to new_identity_password_reset_path, alert: "That password reset link is invalid" if @user.account_suspended?
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
