module ActionAuth
  module Identity
    class EmailVerificationsController < ApplicationController
      before_action :set_user, only: :show

      rate_limit to: 5,
        within: 1.minute,
        only: :create,
        name: "email-verification-throttle",
        with: -> { redirect_to sign_in_path, alert: "Too many requests. Try again later." }

      def show
        @user.update! verified: true
        redirect_to sign_in_path, notice: "Thank you for verifying your email address"
      end

      def create
        user = ActionAuth::User.find_by(email: string_param(:email))
        UserMailer.with(user: user).email_verification.deliver_later if user
        redirect_to sign_in_path, notice: "We sent a verification email to your email address"
      end

      private

      def set_user
        # The "Verify Email" link has no token. It's a way to reach the form that
        # sends one, not a failed verification.
        return redirect_to(edit_identity_email_path) if params[:sid].blank?

        @user = ActionAuth::User.find_by_token_for!(:email_verification, string_param(:sid))
      rescue StandardError
        redirect_to edit_identity_email_path, alert: "That email verification link is invalid"
      end

    end
  end
end
