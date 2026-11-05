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

    def create
      user = user_for_submitted_code

      if user
        user.update(verified: true, sms_code: nil, sms_code_sent_at: nil)
        cookies.delete(:sms_auth_phone_number, action_auth_session_cookie_options)
        complete_sign_in(user, notice: "Signed In")
      else
        redirect_to sign_in_path, alert: "Authentication failed, please try again."
      end
    end

    private

    # Compares one code in Ruby rather than putting it in the query, where an
    # array parameter would let one request try thousands of codes.
    def user_for_submitted_code
      phone_number = cookies.signed[:sms_auth_phone_number]
      code = string_param(:sms_code)
      return unless phone_number.present? && code.present?

      user = User.find_by(phone_number: phone_number, sms_code_sent_at: CODE_LIFETIME.ago..Time.current)
      user if user&.sms_code.present? && ActiveSupport::SecurityUtils.secure_compare(user.sms_code, code)
    end
  end
end
