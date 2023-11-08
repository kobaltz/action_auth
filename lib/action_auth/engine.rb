require 'action_auth/controllers/helpers'
require 'action_auth/routing/helpers'

module ActionAuth
  class Engine < ::Rails::Engine
    isolate_namespace ActionAuth

    ActiveSupport.on_load(:action_controller_base) do
      include ActionAuth::Controllers::Helpers
      include ActionAuth::Routing::Helpers
    end

    initializer 'action_auth.add_helpers' do |app|
      ActiveSupport.on_load :action_controller_base do
        helper_method :user_sessions_path, :user_session_path, :new_user_session_path
        helper_method :new_user_registration_path
      end
    end
  end
end
