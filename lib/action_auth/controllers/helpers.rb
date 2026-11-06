module ActionAuth
  module Controllers
    module Helpers
      extend ActiveSupport::Concern

      ACCOUNT_SUSPENDED_MESSAGE = "This account has been suspended.".freeze

      included do
        before_action :set_current_request_details
        before_action :check_session_timeout
        before_action :check_action_auth_suspension

        def current_user; Current.user; end
        helper_method :current_user

        def current_session; Current.session; end
        helper_method :current_session

        def user_signed_in?; Current.user.present?; end
        helper_method :user_signed_in?

        def authenticate_user!
          return if user_signed_in?
          redirect_to new_user_session_path
        end
        helper_method :authenticate_user!

        # True inside ActionAuth's own controllers. Lets an app that uses
        # config.parent_controller exempt them from its other filters:
        #   before_action :require_subscription, unless: :action_auth_controller?
        def action_auth_controller?; false; end
        helper_method :action_auth_controller?
      end

      private

      def set_current_request_details
        session_token = cookies.signed[:session_token]
        Current.session = Session.find_by(id: session_token) if session_token.present?
        Current.user_agent = request.user_agent
        Current.ip_address = request.ip

        # Check if IP address or user agent has changed
        if Current.session && (Current.session.ip_address != Current.ip_address ||
                              Current.session.user_agent != Current.user_agent)
          Rails.logger.warn "Session environment changed for user #{Current.user&.id}: IP or User-Agent mismatch"
          # Optional: Force re-authentication for suspicious activity
          # delete_action_auth_session_cookie
          # Current.session = nil
        end
      end

      def check_session_timeout
        timeout = ActionAuth.configuration.session_timeout
        return unless Current.session && timeout

        if Current.session.updated_at < timeout.ago
          Rails.logger.info "Session timed out for user #{Current.session.user_id}"
          Current.session.destroy
          Current.session = nil
          delete_action_auth_session_cookie
          redirect_to new_user_session_path, alert: "Your session has expired. Please sign in again."
        elsif Current.session.updated_at < 1.minute.ago
          # Inactivity is tracked to the minute, so most requests don't need a write.
          Current.session.touch
        end
      end

      # suspend_account! already ends the account's sessions. This catches the rest:
      # a suspension set some other way, or a sign in that finished at the same moment.
      def check_action_auth_suspension
        return unless Current.session && User.account_suspension_available?
        return unless Current.session.user.account_suspended?

        Rails.logger.info "Ended a session of suspended user #{Current.session.user_id}"
        Current.session.destroy
        Current.session = nil
        delete_action_auth_session_cookie
        redirect_to new_user_session_path, alert: ACCOUNT_SUSPENDED_MESSAGE
      end

      def action_auth_session_cookie_options
        options = { httponly: true, same_site: :lax }
        options[:secure] = true if Rails.env.production? || request.ssl?
        options[:domain] = :all if ActionAuth.configuration.insert_cookie_domain
        options
      end

      # A cookie can only be deleted with the domain it was set with.
      def delete_action_auth_session_cookie
        cookies.delete(:session_token, action_auth_session_cookie_options)
      end
    end
  end
end
