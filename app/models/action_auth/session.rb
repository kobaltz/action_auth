module ActionAuth
  class Session < ApplicationRecord
    self.table_name = "sessions"

    belongs_to :user, class_name: "ActionAuth::User", foreign_key: "user_id"

    before_create do
      self.user_agent = Current.user_agent
      self.ip_address = Current.ip_address
    end
  end
end
