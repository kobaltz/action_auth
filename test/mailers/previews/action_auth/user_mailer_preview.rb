module ActionAuth
  # Preview all emails at http://localhost:3000/rails/mailers/user_mailer
  class UserMailerPreview < ActionMailer::Preview

    # Preview this email at http://localhost:3000/rails/mailers/user_mailer/email_verification
    def email_verification
      user = User.create(email: "john.smith@example.com", password: "123456789012")
      UserMailer.with(user: user).email_verification
    end

    # Preview this email at http://localhost:3000/rails/mailers/user_mailer/password_reset
    def password_reset
      user = User.create(email: "john.smith@example.com", password: "123456789012")
      UserMailer.with(user: user).password_reset
    end

  end
end
