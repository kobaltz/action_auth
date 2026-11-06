module ActionAuth
  class ConnectedAccountsController < ApplicationController
    before_action :authenticate_user!

    def destroy
      connected_account = Current.user.connected_accounts.find(params[:id])

      if Current.user.can_sign_in_without?(connected_account)
        connected_account.destroy
        redirect_to sessions_path, notice: "#{connected_account.provider_label} has been disconnected.", status: :see_other
      else
        redirect_to sessions_path, alert: "That's the only way to sign in to this account, so it can't be disconnected.", status: :see_other
      end
    end
  end
end
