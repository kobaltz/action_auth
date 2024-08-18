class ActionAuth::WebauthnCredentialsController < ApplicationController
  before_action :authenticate_user!
  layout "action_auth/application"

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
      exclude: current_user.webauthn_credentials.pluck(:external_id)
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
    webauthn_credential = WebAuthn::Credential.from_create(params)

    begin
      webauthn_credential.verify(session[:current_challenge])

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
    rescue WebAuthn::Error => e
      Rails.logger.error "❌ Verification failed: #{e.message}"
      render json: "Verification failed: #{e.message}", status: :unprocessable_entity
    end
  end

  def destroy
    current_user.webauthn_credentials.destroy(params[:id])

    redirect_to sessions_path
  end

  private

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
