module ActionAuth
  class WebauthnCredential < ApplicationRecord
    self.table_name = "webauthn_credentials"

    belongs_to :user, class_name: "ActionAuth::User", optional: true

    validates :external_id, :public_key, :nickname, :sign_count, presence: true
    validates :external_id, uniqueness: true
    validates :sign_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 2**32 - 1
              }

    enum :key_type, {
      unknown: 0,
      passkey: 1,
      hardware: 2,
      wireless: 3
    }
  end
end
