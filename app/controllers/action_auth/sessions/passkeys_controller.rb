module ActionAuth
  module Sessions
    class PasskeysController < ApplicationController
      rate_limit to: 5,
        within: 20.seconds,
        only: :create,
        name: "passkey-throttle",
        with: -> { render json: "Too many attempts. Try again later.", status: :too_many_requests }

      def new
        get_options = WebAuthn::Credential.options_for_get(user_verification: "required")
        session[:current_challenge] = get_options.challenge
        @options = get_options
      end

      # A passkey is the only factor on this path, so it has to prove the user
      # was verified on the device (biometric or PIN), not just present.
      def create
        credential = verify_webauthn_assertion(WebauthnCredential, user_verification: true)

        if credential&.user&.account_suspended?
          render json: ACCOUNT_SUSPENDED_MESSAGE, status: :unprocessable_entity
        elsif credential&.user
          start_session_for(credential.user)
          render json: { status: "ok", redirect_url: after_sign_in_path }
        else
          render json: "That passkey is incorrect", status: :unprocessable_entity
        end
      end
    end
  end
end
