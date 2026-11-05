module ActionAuth
  class Magics::SignInsController < ApplicationController
    INVALID_LINK = "That sign in link has expired or has already been used. Please request a new one.".freeze

    # Mail scanners and link previews open the links in an email, so opening one
    # only asks for confirmation. Otherwise they'd use up the link before the
    # person it was sent to could click it.
    def show
      @user = user_from_token

      redirect_to sign_in_path, alert: INVALID_LINK unless @user
    end

    def create
      user = user_from_token

      if user&.claim_magic_link
        complete_sign_in(user, notice: "Signed In")
      else
        redirect_to sign_in_path, alert: INVALID_LINK, status: :see_other
      end
    end

    private

    def user_from_token
      User.find_by_token_for(:magic_token, string_param(:token))
    end
  end
end
