module ActionAuth
  class Magics::SignInsController < ApplicationController
    def show
      user = ActionAuth::User.find_by_token_for(:magic_token, string_param(:token))

      if user
        user.update(verified: true)
        complete_sign_in(user, notice: "Signed In")
      else
        redirect_to sign_in_path, alert: "Authentication failed, please try again."
      end
    end
  end
end
