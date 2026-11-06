module ActionAuth
  # An account on another site that can be used to sign in to this one. Only what
  # identifies it is stored. There are no access tokens here to leak.
  class ConnectedAccount < ApplicationRecord
    self.table_name = "action_auth_connected_accounts"

    belongs_to :user, class_name: "ActionAuth::User"

    validates :provider, :uid, presence: true
    validates :uid, uniqueness: { scope: :provider }

    # The provider may have been removed from the config since this was connected.
    def provider_label
      configured = ActionAuth.configuration.oauth_providers.find { |oauth| oauth.key == provider }
      configured ? configured.label : provider.titleize
    end
  end
end
