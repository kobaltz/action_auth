module ActionAuth
  class Session < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :user, class_name: "ActionAuth::User", foreign_key: "user_id"

    # The controllers refuse these with a message. This is what guarantees that no
    # path, including a new one or an app's own sign in code, can get past that.
    validate on: :create do
      errors.add(:user, "is suspended") if user&.account_suspended?
    end

    before_create do
      # Some in-app browsers send very long user agents, and a 255 character
      # column on MySQL would refuse them and fail the sign in.
      self.user_agent = Current.user_agent&.first(255)
      self.ip_address = Current.ip_address
    end
  end
end
