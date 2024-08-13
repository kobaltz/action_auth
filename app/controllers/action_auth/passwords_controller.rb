module ActionAuth
  class PasswordsController < ApplicationController
    before_action :set_user
    before_action :validate_pwned_password, only: :update

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

      pwned = Pwned::Password.new(params[:password])
      if pwned.pwned?
        @user.errors.add(:password, "has been pwned #{pwned.pwned_count} times. Please choose a different password.")
        render :new, status: :unprocessable_entity
      end
    end
  end
end
