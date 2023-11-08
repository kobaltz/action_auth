module ActionAuth
  class Current < ActiveSupport::CurrentAttributes
    attribute :session
    attribute :user_agent, :ip_address

    delegate :action_auth_user, to: :session, allow_nil: true

    def user
      action_auth_user
    end
  end
end
