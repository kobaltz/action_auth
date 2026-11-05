module ActionAuth
  module Identity
    class EmailsController < ApplicationController
      # edit stays public: it doubles as the "resend my verification email" form
      # for people who can't sign in yet.
      before_action :authenticate_user!, only: :update
      before_action :set_user

      rate_limit to: 5,
        within: 1.minute,
        only: :update,
        name: "email-change-throttle",
        with: -> { redirect_to edit_identity_email_path, alert: "Too many attempts. Try again later.", status: :see_other }

      def edit
      end

      def update
        if @user.update(user_params)
          redirect_after_update
        else
          # The form shows what was typed from params. Current.user is shared
          # with the rest of the request, so don't leave it holding a rejected email.
          @user.restore_attributes
          render :edit, status: :unprocessable_entity
        end
      end

      private

      def set_user
        @user = Current.user
      end

      def user_params
        params.permit(:email, :password_challenge).with_defaults(password_challenge: "")
      end

      def redirect_after_update
        if @user.email_previously_changed?
          resend_email_verification
          redirect_to sessions_path, notice: "Your email has been changed. Check your email to verify your email.", status: :see_other
        else
          redirect_to sessions_path, status: :see_other
        end
      end

      def resend_email_verification
        UserMailer.with(user: @user).email_verification.deliver_later
      end
    end
  end
end
