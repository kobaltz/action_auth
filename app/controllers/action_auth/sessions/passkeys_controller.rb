module ActionAuth
  module Sessions
    class PasskeysController < ApplicationController
      def new
        get_options = WebAuthn::Credential.options_for_get
        session[:current_challenge] = get_options.challenge
        @options = get_options
      end

      def create
        webauthn_credential = WebAuthn::Credential.from_get(params)
        credential = WebauthnCredential.find_by(external_id: webauthn_credential.id)
        user = User.find_by(id: credential&.user_id)
        if credential && user
          session = user.sessions.create
          cookies.signed.permanent[:session_token] = { value: session.id, httponly: true }
          redirect_to main_app.root_path(format: :html), notice: "Signed in successfully"
        else
          redirect_to sign_in_path(format: :html), alert: "That passkey is incorrect" and return
        end
      end
    end
  end
end
