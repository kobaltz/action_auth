module ActionAuth
  class RegistrationsController < ApplicationController
    before_action :validate_pwned_password, only: :create

    rate_limit to: 3,
      within: 60.seconds,
      only: :create,
      name: "registration-throttle",
      with: -> { redirect_to new_user_registration_path, alert: "Too many registration attempts. Try again later." }

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
          session_record = @user.sessions.create!
          cookie_options = { value: session_record.id, httponly: true }
          cookie_options[:secure] = Rails.env.production? if Rails.env.production?
          cookie_options[:same_site] = :lax unless Rails.env.test?
          cookies.signed.permanent[:session_token] = cookie_options

          redirect_to sign_in_path, notice: "Welcome! You have signed up successfully"
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

    def validate_pwned_password
      return unless ActionAuth.configuration.pwned_enabled?

      if params[:password].present? && !Rails.env.test? && (params[:password] !~ /[A-Z]/ || params[:password] !~ /[a-z]/ || params[:password] !~ /[0-9]/ || params[:password] !~ /[^A-Za-z0-9]/)
        @user = User.new(email: params[:email])
        @user.errors.add(:password, "must include at least one uppercase letter, one lowercase letter, one number, and one special character.")
        render :new, status: :unprocessable_entity and return
      end

      pwned = Pwned::Password.new(params[:password])

      if pwned.pwned?
        @user = User.new(email: params[:email])
        @user.errors.add(:password, "has been pwned #{pwned.pwned_count} times. Please choose a different password.")
        render :new, status: :unprocessable_entity
      end
    end
  end
end
