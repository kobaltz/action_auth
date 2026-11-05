module ActionAuth
  class WebauthnCredentialsController < ApplicationController
    before_action :authenticate_user!

    def new
    end

    def options
      if current_user.webauthn_id.blank?
        current_user.update!(webauthn_id: WebAuthn.generate_user_id)
      end

      create_options = WebAuthn::Credential.options_for_create(
        user: {
          id: current_user.webauthn_id,
          name: current_user.email
        },
        exclude: current_user.webauthn_credentials.pluck(:external_id),
        authenticator_selection: authenticator_selection
      )

      session[:current_challenge] = create_options.challenge

      respond_to do |format|
        format.json { render json: create_options }
        if defined?(Turbo)
          format.turbo_stream { render json: create_options }
        end
      end
    end

    def create
      webauthn_credential = verified_registration
      return render(json: "Verification failed", status: :unprocessable_entity) unless webauthn_credential

      credential = current_user.webauthn_credentials.build(
        external_id: webauthn_credential.id,
        nickname: params[:credential_nickname],
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        key_type: key_type
      )

      if credential.save
        render json: { status: "ok" }, status: :ok
      else
        render json: "Couldn't add your Security Key", status: :unprocessable_entity
      end
    end

    def destroy
      current_user.webauthn_credentials.destroy(params[:id])

      redirect_to sessions_path, status: :see_other
    end

    private

    # Signing in with only a passkey doesn't name an account up front, so the
    # authenticator has to be able to find the credential by itself. Browsers
    # don't create that kind of credential unless asked.
    def authenticator_selection
      ActionAuth.configuration.passkey_only? ? { resident_key: "preferred" } : {}
    end

    # See verify_webauthn_assertion for why this rescues broadly.
    def verified_registration
      challenge = session.delete(:current_challenge)
      WebAuthn::Credential.from_create(params).tap { |credential| credential.verify(challenge) }
    rescue StandardError => e
      Rails.logger.warn "ActionAuth rejected a WebAuthn registration: #{e.class}: #{e.message}"
      nil
    end

    def key_type
      transports = params.dig(:response, :transports)
      return :unknown unless transports.present?

      transport_types = {
        ["internal", "hybrid"] => :passkey,
        ["usb", "nfc"] => :hardware,
        ["bluetooth", "wireless"] => :wireless,
      }.freeze

      transport_types.each do |keys, type|
        if transports.is_a?(String)
          return type if keys.include?(transports)
        elsif transports.is_a?(Array)
          return type if (keys & transports).any?
        end
      end

      :unknown
    end
  end
end
