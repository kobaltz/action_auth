module ActionAuth
  class User < ApplicationRecord
    has_secure_password

    generates_token_for :email_verification, expires_in: 2.days do
      email
    end

    generates_token_for :password_reset, expires_in: 20.minutes do
      password_salt.last(10)
    end


    has_many :action_auth_sessions, dependent: :destroy, class_name: "ActionAuth::Session", foreign_key: "action_auth_user_id"

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, allow_nil: true, length: { minimum: 12 }

    normalizes :email, with: -> email { email.strip.downcase }


    before_validation if: :email_changed?, on: :update do
      self.verified = false
    end

    after_update if: :password_digest_previously_changed? do
      action_auth_sessions.where.not(id: Current.session).delete_all
    end
  end
end
