module ActionAuth
  module Controllers
    module Helpers
      extend ActiveSupport::Concern

      included do
        before_action :set_current_request_details
        before_action :check_session_timeout

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
      end

      private

      def set_current_request_details
        Current.session = Session.find_by(id: cookies.signed[:session_token])
        Current.user_agent = request.user_agent
        Current.ip_address = request.ip

        # Check if IP address or user agent has changed
        if Current.session && (Current.session.ip_address != Current.ip_address ||
                              Current.session.user_agent != Current.user_agent)
          Rails.logger.warn "Session environment changed for user #{Current.user&.id}: IP or User-Agent mismatch"
          # Optional: Force re-authentication for suspicious activity
          # cookies.delete(:session_token, secure: Rails.env.production?, same_site: :lax)
          # Current.session = nil
        end
      end

      def check_session_timeout
        return unless Current.session
        return if Rails.env.test?

        timeout = ActionAuth.configuration.session_timeout
        if Current.session.updated_at < timeout.ago
          Rails.logger.info "Session timed out for user #{Current.user&.id}"
          Current.session.destroy
          cookie_options = {}
          cookie_options[:secure] = Rails.env.production? if Rails.env.production?
          cookie_options[:same_site] = :lax unless Rails.env.test?
          cookies.delete(:session_token, cookie_options)
          redirect_to new_user_session_path, alert: "Your session has expired. Please sign in again."
        else
          Current.session.touch
        end
      end
    end
  end
end
