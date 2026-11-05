module ActionAuth
  class PasswordsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user

    rate_limit to: 3,
      within: 60.seconds,
      only: :update,
      name: "password-reset-throttle",
      with: -> { redirect_to edit_password_path, alert: "Too many password change attempts. Try again later.", status: :see_other }

    before_action :validate_new_password, only: :update

    def edit
    end

    def update
      if @user.update(user_params)
        redirect_to sessions_path, notice: "Your password has been changed", status: :see_other
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

    def validate_new_password
      reject_unusable_password(@user, :edit)
    end
  end
end
