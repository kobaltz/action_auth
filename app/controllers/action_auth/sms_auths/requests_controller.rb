module ActionAuth
  class SmsAuths::RequestsController < ApplicationController
    def new
    end

    def create
      @user = User.find_or_initialize_by(phone_number: params[:phone_number])
      if @user.new_record?
        password = generate_compliant_password

        @user.email = "#{SecureRandom.hex(32)}@smsauth"
        @user.password = password
        @user.password_confirmation = password
        @user.verified = false

        @user.save!
      end

      code = rand(100_000..999_999)
      @user.update!(sms_code: code, sms_code_sent_at: Time.current)
      cookies.signed[:sms_auth_phone_number] = { value: @user.phone_number, httponly: true }

      if defined?(ActionAuth.configuration.sms_send_class) &&
        ActionAuth.configuration.sms_send_class.respond_to?(:send_code)
        ActionAuth.configuration.sms_send_class.send_code(@user.phone_number, code)
      end

      redirect_to sms_auths_sign_ins_path, notice: "Check your phone for a SMS Code."
    end
  end
end
