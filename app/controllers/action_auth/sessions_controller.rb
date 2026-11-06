module ActionAuth
  class SessionsController < ApplicationController
    before_action :authenticate_user!, only: [:index, :destroy]

    rate_limit to: 5,
      within: 20.seconds,
      only: :create,
      name: "slow-throttle",
      with: -> { redirect_to sign_in_path, alert: "Try again later." }

    def index
      @action_auth_wide = true
      @sessions = Current.user.sessions.order(created_at: :desc)
    end

    def new
    end

    # A locked account gets the same answer whether or not the password is right.
    # Saying "locked" only to the right password would let guessing carry on through
    # the lock, and saying it to anyone would reveal who has an account. The account's
    # owner finds out by email instead.
    def create
      user = User.authenticate_by(email: string_param(:email), password: string_param(:password))

      if user && !user.account_locked?
        return if check_if_email_is_verified(user)

        complete_sign_in(user, notice: "Signed in successfully")
      else
        # An empty form isn't a guess.
        record_failed_sign_in(user || User.find_by(email: string_param(:email))) if string_param(:password).present?

        redirect_to sign_in_path(email_hint: string_param(:email)), alert: "That email or password is incorrect"
      end
    end

    def destroy
      user_session = Current.user.sessions.find(params[:id])
      user_session.destroy

      if user_session == Current.session
        Current.session = nil
        delete_action_auth_session_cookie
        response.headers["Clear-Site-Data"] = '"cache","storage"'
        redirect_to after_sign_out_path, notice: "That session has been logged out", status: :see_other
      else
        # Another device was signed out. This one stays signed in.
        redirect_to sessions_path, notice: "That session has been logged out", status: :see_other
      end
    end

    private

    def check_if_email_is_verified(user)
      return false unless ActionAuth.configuration.verify_email_on_sign_in
      return false if user.verified?

      redirect_to sign_in_path(email_hint: string_param(:email)),
        alert: "You must verify your email before you sign in."
    end
  end
end
