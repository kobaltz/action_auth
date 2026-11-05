require "rails/generators"

module ActionAuth
  module Generators
    class ViewsGenerator < Rails::Generators::Base
      SCOPES = %w[
        sessions
        registrations
        passwords
        identity
        magics
        sms_auths
        webauthn_credentials
        webauthn_credential_authentications
        user_mailer
        shared
      ].freeze

      source_root File.expand_path("../../../../app/views", __dir__)

      desc "Copies ActionAuth's views into your app so you can change them."

      argument :scopes, type: :array, default: [], banner: "scope scope ...",
        desc: "Only copy these groups of views: #{SCOPES.join(', ')}"

      class_option :layout, type: :boolean, default: false,
        desc: "Also copy layouts/action_auth/application.html.erb"

      def check_scopes
        unknown = scopes - SCOPES
        return if unknown.empty?

        raise Thor::Error, "Unknown scope: #{unknown.join(', ')}. Choose from: #{SCOPES.join(', ')}"
      end

      def copy_views
        (scopes.presence || SCOPES).each do |scope|
          directory "action_auth/#{scope}", "app/views/action_auth/#{scope}"
        end
      end

      def copy_layout
        return unless options[:layout]

        copy_file "layouts/action_auth/application.html.erb", "app/views/layouts/action_auth/application.html.erb"
      end

      def show_next_steps
        say <<~MESSAGE

          Your copies now take priority over the ones in the gem, but they also
          won't pick up changes from future ActionAuth versions. Delete any you
          didn't change so they keep following the gem.

        MESSAGE
      end
    end
  end
end
