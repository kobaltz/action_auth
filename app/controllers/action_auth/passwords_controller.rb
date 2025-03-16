module ActionAuth
  class PasswordsController < ApplicationController
    before_action :set_user
    before_action :validate_pwned_password, only: :update

    rate_limit to: 3,
      within: 60.seconds,
      only: :update,
      name: "password-reset-throttle",
      with: -> { redirect_to sign_in_path, alert: "Too many password reset attempts. Try again later." }

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to sign_in_path, notice: "Your password has been changed"
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = Current.user
    end

    def user_params
      params.permit(:password, :password_confirmation, :password_challenge).with_defaults(password_challenge: "")
    end

    def validate_pwned_password
      return unless ActionAuth.configuration.pwned_enabled?

      # Check minimum password requirements
      if params[:password].present? && ActionAuth.configuration.password_complexity_check? && !Rails.env.test? &&
         (params[:password] !~ /[A-Z]/ || params[:password] !~ /[a-z]/ || params[:password] !~ /[0-9]/ || params[:password] !~ /[^A-Za-z0-9]/)
        @user.errors.add(:password, "must include at least one uppercase letter, one lowercase letter, one number, and one special character.")
        render :edit, status: :unprocessable_entity and return
      end

      pwned = Pwned::Password.new(params[:password])
      if pwned.pwned?
        @user.errors.add(:password, "has been pwned #{pwned.pwned_count} times. Please choose a different password.")
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
