require 'twilio-ruby'

class SmsSender
  def self.send_code(phone_number, code)
    client = Twilio::REST::Client.new(
      ENV['TWILIO_ACCOUNT_SID'],
      ENV['TWILIO_AUTH_TOKEN']
    )

    client.messages.create(
      from: ENV['TWILIO_PHONE_NUMBER'],
      to: phone_number,
      body: "Your verification code is #{code}"
    )
  end
end
