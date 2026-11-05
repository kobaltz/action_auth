module ActionAuth
  class RegistrationsController < ApplicationController
    rate_limit to: 3,
      within: 60.seconds,
      only: :create,
      name: "registration-throttle",
      with: -> { redirect_to new_user_registration_path, alert: "Too many registration attempts. Try again later." }

    before_action :validate_new_password, only: :create

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        if ActionAuth.configuration.verify_email_on_sign_in
          send_email_verification
          redirect_to sign_in_path, notice: "Welcome! You have signed up successfully. Please check your email to verify your account."
        else
          start_session_for(@user)
          redirect_to after_sign_in_path, notice: "Welcome! You have signed up successfully"
        end
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def user_params
      params.permit(:email, :password, :password_confirmation)
    end

    def send_email_verification
      UserMailer.with(user: @user).email_verification.deliver_later
    end

    def validate_new_password
      @user = User.new(email: string_param(:email))
      reject_unusable_password(@user, :new)
    end
  end
end
