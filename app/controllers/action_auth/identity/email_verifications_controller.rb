module ActionAuth
  module Identity
    class EmailVerificationsController < ApplicationController
      before_action :set_user, only: :show

      def show
        @user.update! verified: true
        redirect_to main_app.root_path, notice: "Thank you for verifying your email address"
      end

      def create
        send_email_verification
        redirect_to main_app.root_path, notice: "We sent a verification email to your email address"
      end

      private

      def set_user
        @user = ActionAuth::User.find_by_token_for!(:email_verification, params[:sid])
      rescue StandardError
        redirect_to edit_identity_email_path, alert: "That email verification link is invalid"
      end

      def send_email_verification
        return unless Current.user
        UserMailer.with(user: Current.user).email_verification.deliver_later
      end
    end
  end
end
