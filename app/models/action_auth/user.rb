module ActionAuth
  class User < ApplicationRecord
    self.table_name = "users"

    has_secure_password

    has_many :sessions, dependent: :destroy,
      class_name: "ActionAuth::Session", foreign_key: "user_id"

    if ActionAuth.configuration.webauthn_enabled?
      has_many :webauthn_credentials, dependent: :destroy,
        class_name: "ActionAuth::WebauthnCredential", foreign_key: "user_id"
    end

    generates_token_for :email_verification, expires_in: 2.days do
      email
    end

    generates_token_for :password_reset, expires_in: 20.minutes do
      password_salt.last(10)
    end

    generates_token_for :magic_token, expires_in: 20.minutes do
      password_salt.last(10)
    end

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, allow_nil: true, length: { minimum: 12 }
    validate :password_complexity, if: -> { ActionAuth.configuration.password_complexity_check? && password.present? && !Rails.env.test? }
    validates :phone_number,
              allow_nil: true,
              uniqueness: true,
              format: {
                with: /\A\+\d+\z/,
                message: "must be a valid international phone number with digits only after the country code"
              }

    normalizes :phone_number, with: -> phone_number { phone_number.gsub(/[^+\d]/, '') }
    normalizes :email, with: -> email { email.strip.downcase }

    before_validation if: :email_changed?, on: :update do
      self.verified = false
    end

    after_update if: :password_digest_previously_changed? do
      sessions.where.not(id: Current.session).delete_all
    end

    def second_factor_enabled?
      return false unless ActionAuth.configuration.webauthn_enabled?
      webauthn_credentials.any?
    end

    private

    def password_complexity
      return if password.blank?

      unless password =~ /[A-Z]/ && password =~ /[a-z]/ && password =~ /[0-9]/ && password =~ /[^A-Za-z0-9]/
        errors.add(:password, "must include at least one uppercase letter, one lowercase letter, one number, and one special character")
      end
    end
  end
end
