module ActionAuth
  module ApplicationHelper
    WEBAUTHN_SCREENS = %w[
      action_auth/webauthn_credentials
      action_auth/webauthn_credential_authentications
      action_auth/sessions/passkeys
    ].freeze

    # The other auth screens someone could go to from here, as [label, path]
    # pairs, leaving out the current page and any feature that's turned off.
    # Use this in a custom view to style the links without repeating the checks:
    #
    #   <% action_auth_links.each do |label, path| %>
    #     <%= link_to label, path, class: "underline" %>
    #   <% end %>
    def action_auth_links
      config = ActionAuth.configuration

      links = [["Sign In", sign_in_path], ["Sign Up", sign_up_path]]
      links << ["Magic Link", new_magics_requests_path] if config.magic_link_enabled?
      links << ["SMS Auth", new_sms_auths_requests_path] if config.sms_auth_enabled?
      links << ["Passkey", new_sessions_passkey_path] if config.passkey_only?
      links << ["Reset Password", new_identity_password_reset_path]
      links << ["Verify Email", edit_identity_email_path] if config.verify_email_on_sign_in

      links.reject { |_label, path| current_page?(path) }
    end

    # Everything the browser side of WebAuthn needs. The three screens that use
    # it include this themselves, so they work inside any layout, and the
    # third-party scripts it loads stay off the pages where people type passwords.
    # Only renders once per page, so it's safe to call from a view and a layout.
    def action_auth_webauthn_tags
      return if @action_auth_webauthn_tags_rendered

      @action_auth_webauthn_tags_rendered = true

      safe_join([
        csrf_meta_tags,
        tag.meta(name: "webauthn_auth_url", content: webauthn_credential_authentications_url),
        tag.meta(name: "webauthn_cred_url", content: webauthn_credentials_url),
        tag.meta(name: "webauthn_redirect_url", content: sessions_url),
        javascript_include_tag("action_auth/application", type: "module", "data-turbo-track": "reload")
      ].compact, "\n")
    end

    # For the default layout, so that a WebAuthn view copied from an older version
    # of ActionAuth, which relied on the layout for these tags, keeps working.
    def action_auth_webauthn_screen?
      controller_path.in?(WEBAUTHN_SCREENS)
    end

    # Engine views only have the engine's routes, so an app's layout would blow
    # up on its first root_path or posts_path. Fall back to the app's routes.
    # The engine's routes still win when both define the same name, so use
    # main_app.session_path for an app route that clashes.
    def method_missing(name, *args, **options, &block)
      if action_auth_main_app_route?(name)
        main_app.public_send(name, *args, **options, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      action_auth_main_app_route?(name) || super
    end

    private

    def action_auth_main_app_route?(name)
      name.end_with?("_path", "_url") && main_app.respond_to?(name)
    end
  end
end
