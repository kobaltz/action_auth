module ActionAuth
  class SmsAuths::RequestsController < ApplicationController
    TOO_MANY_REQUESTS = -> { redirect_to new_sms_auths_requests_path, alert: "Too many requests. Try again later." }

    # Every message sent costs money, so limit both how fast one client can send
    # to many numbers and how often any one number can be texted.
    rate_limit to: 3, within: 1.minute, only: :create, name: "sms-request-throttle", with: TOO_MANY_REQUESTS
    rate_limit to: 3, within: 5.minutes, only: :create, name: "sms-number-throttle",
      by: -> { User.normalize_value_for(:phone_number, string_param(:phone_number)) }, with: TOO_MANY_REQUESTS

    def new
    end

    def create
      # Never nil: searching for a nil phone number would match every account that
      # doesn't have one.
      @user = User.find_or_initialize_by(phone_number: string_param(:phone_number))

      if @user.new_record?
        @user.email = "#{SecureRandom.hex(32)}@smsauth"
        @user.password = @user.password_confirmation = generate_compliant_password
        @user.verified = false

        unless @user.save
          flash.now[:alert] = @user.errors.full_messages_for(:phone_number).to_sentence
          return render :new, status: :unprocessable_entity
        end
      end

      code = SecureRandom.random_number(100_000..999_999)
      @user.update!(sms_code: code, sms_code_sent_at: Time.current)
      cookies.signed[:sms_auth_phone_number] = action_auth_session_cookie_options.merge(value: @user.phone_number)

      send_code(@user.phone_number, code)

      redirect_to sms_auths_sign_ins_path, notice: "Check your phone for a SMS Code."
    end

    private

    def send_code(phone_number, code)
      sender = ActionAuth.configuration.sms_send_class

      if sender.respond_to?(:send_code)
        sender.send_code(phone_number, code)
      else
        Rails.logger.error "ActionAuth could not send an SMS code: config.sms_send_class must respond to send_code"
      end
    end
  end
end
