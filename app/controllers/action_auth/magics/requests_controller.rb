module ActionAuth
  class Magics::RequestsController < ApplicationController
    def new
    end

    def create
      user = User.find_or_initialize_by(email: params[:email])
      if user.new_record?
        password = SecureRandom.hex(32)
        user.password = password
        user.password_confirmation = password
        user.save!
      end

      UserMailer.with(user: user).magic_link.deliver_later

      redirect_to sign_in_path, notice: "Check your email for a magic link."
    end
  end
end
