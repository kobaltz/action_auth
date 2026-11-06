module ActionAuth
  class User < ApplicationRecord
    self.table_name = "users"

    SMS_EMAIL_SUFFIX = "@smsauth".freeze
    OAUTH_EMAIL_SUFFIX = "@oauth".freeze

    has_secure_password

    has_many :sessions, dependent: :destroy,
      class_name: "ActionAuth::Session", foreign_key: "user_id"

    if ActionAuth.configuration.webauthn_enabled?
      has_many :webauthn_credentials, dependent: :destroy,
        class_name: "ActionAuth::WebauthnCredential", foreign_key: "user_id"
    end

    # No dependent option, because that would query a table that doesn't exist until
    # the app has run the migration. The foreign key removes these with the user.
    has_many :connected_accounts, class_name: "ActionAuth::ConnectedAccount", foreign_key: "user_id"

    generates_token_for :email_verification, expires_in: 2.days do
      email
    end

    generates_token_for :password_reset, expires_in: 20.minutes do
      password_salt.last(10)
    end

    generates_token_for :magic_token, expires_in: 20.minutes do
      [password_salt.last(10), email, magic_link_used_at]
    end

    validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :password, allow_nil: true, length: { minimum: 12 }
    validate :password_complexity, if: -> { ActionAuth.configuration.password_complexity_check? && password.present? }
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
      sessions.where.not(id: Current.session&.id).delete_all
      unlock_account!
    end

    # Lockout and suspension are on by default, so they're switched on for apps that
    # have upgraded the gem but not yet run the migration. Until it has run they do
    # nothing, rather than breaking sign in for everyone.
    def self.account_lockout_available?
      ActionAuth.configuration.account_lockout_enabled? && column_names.include?("account_locked_at")
    end

    def self.account_suspension_available?
      ActionAuth.configuration.account_suspension_enabled? && column_names.include?("account_suspended_at")
    end

    def second_factor_enabled?
      return false unless ActionAuth.configuration.webauthn_enabled?
      webauthn_credentials.any?
    end

    # Uses up every magic link sent so far, since their tokens include this value.
    # Returns false to all but one of several simultaneous clicks: the update only
    # matches if nobody has changed these values since this record was loaded. Holding
    # a link also proves the email address is theirs. In a transaction, because a claim
    # that half happened couldn't be tried again: the account would already be verified.
    def claim_magic_link
      address_was_unproven = !verified?
      now = Time.current

      transaction do
        claimed = self.class.where(id: id, verified: verified, magic_link_used_at: magic_link_used_at)
          .update_all(magic_link_used_at: now, verified: true, updated_at: now)
        next false unless claimed == 1

        reload
        remove_access_from_before_address_was_proven if address_was_unproven
        true
      end
    end

    # An account made by signing in with SMS, or through a provider that doesn't
    # share an email address, has a random password and a placeholder email address,
    # so nobody can know that password or reset it.
    def password_usable?
      !email.end_with?(SMS_EMAIL_SUFFIX, OAUTH_EMAIL_SUFFIX)
    end

    # How someone without a usable password proves it's them.
    def fresh_sign_in_method
      email.end_with?(OAUTH_EMAIL_SUFFIX) ? "your connected account" : "a new SMS code"
    end

    # Whether disconnecting +connected_account+ would leave a way to sign in.
    def can_sign_in_without?(connected_account)
      config = ActionAuth.configuration

      password_usable? ||
        connected_accounts.where.not(id: connected_account.id).exists? ||
        (config.passkey_only? && webauthn_credentials.exists?) ||
        (config.sms_auth_enabled? && phone_number.present?)
    end

    # Locks out the guessable factors, passwords and SMS codes. A magic link, passkey
    # or connected account can't be guessed, so they still work. Without that, anyone
    # who knew an email address could keep its owner out by failing on purpose.
    def account_locked?
      return false unless self.class.account_lockout_available? && account_locked_at

      duration = ActionAuth.configuration.account_lockout_duration
      duration.nil? || account_locked_at > duration.ago
    end

    # Counts a failed guess, and returns true if it's the one that locked the account.
    # Uses single statements so that simultaneous guesses are all counted and only one
    # of them locks the account, and an attempt during a lock doesn't extend it.
    def register_failed_sign_in
      unless self.class.account_lockout_available?
        warn_about_lockout_migration
        return false
      end
      return false if account_locked?

      config = ActionAuth.configuration
      account = self.class.where(id: id)

      # Failures from a lock that has run out don't count towards the next one.
      if config.account_lockout_duration
        account.where(account_locked_at: ..config.account_lockout_duration.ago)
          .update_all(account_locked_at: nil, failed_sign_in_attempts: 0)
      end

      self.class.update_counters(id, failed_sign_in_attempts: 1)
      locked = account.where(account_locked_at: nil, failed_sign_in_attempts: config.account_lockout_max_attempts..)
        .update_all(account_locked_at: Time.current)

      reload
      locked == 1
    end

    # Also runs whenever someone signs in or changes the password, which ends any
    # lock and restarts the count.
    def unlock_account!
      return unless self.class.account_lockout_available?
      return if failed_sign_in_attempts.zero? && account_locked_at.nil?

      update_columns(failed_sign_in_attempts: 0, account_locked_at: nil)
    end

    def account_suspended?
      self.class.account_suspension_available? && account_suspended_at.present?
    end

    # Blocks every way of signing in and signs the account out everywhere, until
    # unsuspend_account!. Skips validations, because an old account that no longer
    # passes them still has to be suspendable. Raises if it can't take effect, since
    # someone suspending an account needs to know it didn't work.
    def suspend_account!
      unless self.class.account_suspension_available?
        raise "ActionAuth can't suspend accounts. Check config.account_suspension_enabled, and run: " \
          "bin/rails action_auth:install:migrations db:migrate"
      end

      transaction do
        self.account_suspended_at = Time.current
        save!(validate: false)
        sessions.delete_all
      end
    end

    def unsuspend_account!
      self.account_suspended_at = nil
      save!(validate: false)
    end

    private

    # Until now nobody had shown this address is theirs, so whoever set this account
    # up may be a stranger: anyone can sign up with someone else's address, or change
    # their own account to it. The address's owner mustn't end up sharing the account
    # with them, so nothing from before this point can still get in.
    #
    # Security keys stay. They're still asked for after a magic link, so a stranger's
    # key keeps the owner out rather than letting the two share an account, and removing
    # keys would let someone holding only the inbox get past a second factor.
    def remove_access_from_before_address_was_proven
      self.password = SecureRandom.base58(32)
      save!(validate: false)
      sessions.delete_all
      connected_accounts.destroy_all if ConnectedAccount.table_exists?
    end

    def warn_about_lockout_migration
      return unless ActionAuth.configuration.account_lockout_enabled?

      Rails.logger.warn "ActionAuth account lockout isn't active yet. Run: bin/rails action_auth:install:migrations db:migrate"
    end

    def password_complexity
      return if password.blank?

      unless password =~ /[A-Z]/ && password =~ /[a-z]/ && password =~ /[0-9]/ && password =~ /[^A-Za-z0-9]/
        errors.add(:password, "must include at least one uppercase letter, one lowercase letter, one number, and one special character")
      end
    end
  end
end
