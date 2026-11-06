module ActionAuth
  # Preview all emails at http://localhost:3000/rails/mailers/action_auth/user_mailer
  class UserMailerPreview < ActionMailer::Preview
    def email_verification
      UserMailer.with(user: preview_user).email_verification
    end

    def password_reset
      UserMailer.with(user: preview_user).password_reset
    end

    def magic_link
      UserMailer.with(user: preview_user).magic_link
    end

    def account_locked
      UserMailer.with(user: preview_user).account_locked
    end

    private

    def preview_user
      User.find_or_create_by!(email: "john.smith@example.com") do |user|
        user.password = "Pr3view$Passw0rd!"
      end
    end
  end
end
