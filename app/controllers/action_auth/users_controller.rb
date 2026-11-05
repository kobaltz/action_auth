module ActionAuth
  class UsersController < ApplicationController
    before_action :authenticate_user!

    def destroy
      Current.user.destroy
      delete_action_auth_session_cookie
      redirect_to after_sign_out_path, notice: "Your account has been deleted.", status: :see_other
    end
  end
end
