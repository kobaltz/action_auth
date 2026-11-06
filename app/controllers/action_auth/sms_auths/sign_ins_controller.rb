module ActionAuth
  class SmsAuths::SignInsController < ApplicationController
    CODE_LIFETIME = 5.minutes

    TOO_MANY_ATTEMPTS = -> { redirect_to sign_in_path, alert: "Too many attempts. Try again later." }

    # A six digit code is only safe if it can't be guessed at speed, so limit
    # guesses per client and against any one phone number.
    rate_limit to: 5, within: 1.minute, only: :create, name: "sms-sign-in-throttle", with: TOO_MANY_ATTEMPTS
    rate_limit to: 5, within: CODE_LIFETIME, only: :create, name: "sms-code-throttle",
      by: -> { cookies.signed[:sms_auth_phone_number].to_s }, with: TOO_MANY_ATTEMPTS

    def show
    end

    # The rate limits above depend on the app's cache. Lockout is the backstop on
    # guessing a code that doesn't, and it says so whether or not the code is right.
    def create
      user = user_for_phone_number

      if user&.account_locked?
        instance_exec(&TOO_MANY_ATTEMPTS)
      elsif user && submitted_code_matches?(user)
        user.update(verified: true, sms_code: nil, sms_code_sent_at: nil)
        cookies.delete(:sms_auth_phone_number, action_auth_session_cookie_options)
        complete_sign_in(user, notice: "Signed In")
      else
        record_failed_sign_in(user) if string_param(:sms_code).present?
        redirect_to sign_in_path, alert: "Authentication failed, please try again."
      end
    end

    private

    # Never searches for a blank number, which would match every account without one.
    def user_for_phone_number
      phone_number = cookies.signed[:sms_auth_phone_number]

      User.find_by(phone_number: phone_number) if phone_number.present?
    end

    # Compares one code in Ruby rather than putting it in the query, where an
    # array parameter would let one request try thousands of codes.
    def submitted_code_matches?(user)
      code = string_param(:sms_code)
      return false unless code.present? && user.sms_code.present?
      return false unless user.sms_code_sent_at&.between?(CODE_LIFETIME.ago, Time.current)

      ActiveSupport::SecurityUtils.secure_compare(user.sms_code, code)
    end
  end
end
