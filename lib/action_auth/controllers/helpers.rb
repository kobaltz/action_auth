module ActionAuth
  module Controllers
    module Helpers
      extend ActiveSupport::Concern

      included do
        before_action :set_current_request_details

        def current_user; Current.user; end
        helper_method :current_user

        def current_session; Current.session; end
        helper_method :current_session

        def user_signed_in?; Current.user.present?; end
        helper_method :user_signed_in?
      end

      private

      def set_current_request_details
        Current.session = Session.find_by(id: cookies.signed[:session_token])
        Current.user_agent = request.user_agent
        Current.ip_address = request.ip
      end
    end
  end
end
