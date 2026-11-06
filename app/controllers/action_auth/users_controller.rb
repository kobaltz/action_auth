module ActionAuth
  class UsersController < ApplicationController
    RECENT_SIGN_IN = 10.minutes

    before_action :authenticate_user!

    # Per session, because this is a way to guess the password of whoever left
    # themselves signed in, and that shouldn't get easier from more IP addresses.
    rate_limit to: 5,
      within: 1.minute,
      only: :destroy,
      name: "account-deletion-throttle",
      by: -> { Current.session.id },
      with: -> { redirect_to sessions_path, alert: "Too many attempts. Try again later.", status: :see_other }

    def destroy
      if Current.user.password_usable?
        return refuse("Your account wasn't deleted because the password was missing or incorrect.") unless password_confirmed?
      else
        return refuse("Please sign in again with #{Current.user.fresh_sign_in_method}, then delete your account within 10 minutes.") unless recently_signed_in?
      end

      Current.user.destroy
      delete_action_auth_session_cookie
      redirect_to after_sign_out_path, notice: "Your account has been deleted.", status: :see_other
    end

    private

    def password_confirmed?
      Current.user.authenticate(string_param(:password_challenge))
    end

    # A new SMS code or provider sign in proves the same thing a password would. This uses created_at
    # because updated_at keeps moving while the session is being used.
    def recently_signed_in?
      Current.session.created_at > RECENT_SIGN_IN.ago
    end

    def refuse(message)
      redirect_to sessions_path, alert: message, status: :see_other
    end
  end
end
