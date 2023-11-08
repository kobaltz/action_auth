module ActionAuth
  module Routing
    module Helpers
      def user_sessions_path
        action_auth.sessions_path
      end

      def user_session_path(session_id)
        action_auth.session_path(session_id)
      end

      def new_user_session_path
        action_auth.sign_in_path
      end

      def new_user_registration_path
        action_auth.sign_up_path
      end
    end
  end
end
