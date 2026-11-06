module ActionAuth
  module Identity
    class EmailVerificationsController < ApplicationController
      before_action :set_user, only: [:show, :update]

      rate_limit to: 5,
        within: 1.minute,
        only: :create,
        name: "email-verification-throttle",
        with: -> { redirect_to sign_in_path, alert: "Too many requests. Try again later." }

      rate_limit to: 5,
        within: 1.minute,
        only: :update,
        name: "email-verification-password-throttle",
        with: -> { redirect_to sign_in_path, alert: "Too many attempts. Try again later.", status: :see_other }

      # Mail scanners and link previews open the links in an email, so opening one
      # changes nothing. It only asks for the password.
      def show
        redirect_to sign_in_path, notice: "Your email address is already verified" if @user.verified?
      end

      # A locked account gets the same answer whether or not the password is right, as
      # it does at sign in, so that this can't be used to carry on guessing.
      def update
        if @user.verify_email_with_password(string_param(:password))
          redirect_to sign_in_path, notice: "Thank you for verifying your email address", status: :see_other
        else
          # An empty form isn't a guess.
          record_failed_sign_in(@user) if string_param(:password).present?

          flash.now[:alert] = "That password is incorrect"
          render :show, status: :unprocessable_entity
        end
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
