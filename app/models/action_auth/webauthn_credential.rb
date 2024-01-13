module ActionAuth
  class WebauthnCredential < ApplicationRecord
    validates :external_id, :public_key, :nickname, :sign_count, presence: true
    validates :external_id, uniqueness: true
    validates :sign_count,
              numericality: {
                only_integer: true,
                greater_than_or_equal_to: 0,
                less_than_or_equal_to: 2**32 - 1
              }
  end
end
