module ActionAuth
  class Session < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :user, class_name: "ActionAuth::User", foreign_key: "user_id"

    before_create do
      # Some in-app browsers send very long user agents, and a 255 character
      # column on MySQL would refuse them and fail the sign in.
      self.user_agent = Current.user_agent&.first(255)
      self.ip_address = Current.ip_address
    end
  end
end
