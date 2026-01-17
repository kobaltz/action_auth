module ActionAuth
  class ApplicationController < ActionController::Base
    private

    def generate_compliant_password
      uppercase = ('A'..'Z').to_a.sample
      lowercase = ('a'..'z').to_a.sample
      digit = ('0'..'9').to_a.sample
      special = %w[! @ # $ % ^ & * ( ) _ + - = [ ] { } | ; : , . < > ?].sample
      random_chars = SecureRandom.alphanumeric(28)
      (random_chars + uppercase + lowercase + digit + special).chars.shuffle.join
    end
  end
end
