module ActionAuth
  class UsersController < ApplicationController
    before_action :authenticate_user!

    def destroy
      Current.user.destroy
      redirect_to main_app.root_url, notice: "Your account has been deleted."
    end
  end
end
