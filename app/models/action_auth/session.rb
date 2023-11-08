module ActionAuth
  class Session < ApplicationRecord
    belongs_to :action_auth_user, class_name: "ActionAuth::User", foreign_key: "action_auth_user_id"

    before_create do
      self.user_agent = Current.user_agent
      self.ip_address = Current.ip_address
    end
  end
end
