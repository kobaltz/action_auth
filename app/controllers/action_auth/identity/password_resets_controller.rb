module ActionAuth
  module Identity
    class PasswordResetsController < ApplicationController
      before_action :set_user, only: %i[ edit update ]
      before_action :validate_pwned_password, only: :update

      def new
      end

      def edit
      end

      def create
        if @user = ActionAuth::User.find_by(email: params[:email], verified: true)
          send_password_reset_email
          redirect_to sign_in_path, notice: "Check your email for reset instructions"
        else
          redirect_to sign_in_path, alert: "You can't reset your password until you verify your email"
        end
      end

      def update
        if @user.update(user_params)
          redirect_to sign_in_path, notice: "Your password was reset successfully. Please sign in"
        else
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = ActionAuth::User.find_by_token_for!(:password_reset, params[:sid])
      rescue StandardError
        redirect_to new_identity_password_reset_path, alert: "That password reset link is invalid"
      end

      def user_params
        params.permit(:password, :password_confirmation)
      end

      def send_password_reset_email
        UserMailer.with(user: @user).password_reset.deliver_later
      end

      def validate_pwned_password
        return unless ActionAuth.configuration.pwned_enabled?

        pwned = Pwned::Password.new(params[:password])
        if pwned.pwned?
          @user.errors.add(:password, "has been pwned #{pwned.pwned_count} times. Please choose a different password.")
          render :edit, status: :unprocessable_entity
        end
      end
    end
  end
end
