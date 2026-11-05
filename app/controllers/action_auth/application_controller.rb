module ActionAuth
  class ApplicationController < ActionAuth.configuration.parent_controller.constantize
    # A host parent controller usually requires sign in for everything, which
    # would make the sign in page unreachable. Each controller here opts back in
    # to authenticate_user! on the actions that need it.
    skip_before_action :authenticate_user!, raise: false

    protect_from_forgery with: :exception

    layout -> { ActionAuth.configuration.layout }

    helper_method :after_sign_in_path, :after_sign_out_path

    private

    def action_auth_controller?
      true
    end

    # Rails turns email[]=x into an Array and email[a]=b into a Hash. Neither is a
    # valid answer to any question these forms ask, so they count as blank.
    def string_param(name)
      value = params[name]
      value.is_a?(String) ? value : ""
    end

    def after_sign_in_path
      action_auth_redirect_path(ActionAuth.configuration.after_sign_in_path)
    end

    def after_sign_out_path
      action_auth_redirect_path(ActionAuth.configuration.after_sign_out_path)
    end

    def action_auth_redirect_path(configured)
      return instance_exec(&configured) if configured.respond_to?(:call)

      configured || main_app.root_path
    end

    # Every first factor (password, magic link, SMS) ends here, so that an
    # account with a security key always gets prompted for it.
    def complete_sign_in(user, notice:)
      if user.second_factor_enabled?
        session[:webauthn_user_id] = user.id
        redirect_to new_webauthn_credential_authentications_path
      else
        start_session_for(user)
        redirect_to after_sign_in_path, notice: notice
      end
    end

    def start_session_for(user)
      user.sessions.create!.tap do |user_session|
        cookies.signed.permanent[:session_token] = action_auth_session_cookie_options.merge(value: user_session.id)
      end
    end

    # Checks the assertion the browser posted against one of +credentials+ and
    # the challenge issued to this session. Returns the credential, or nil if it
    # doesn't verify.
    #
    # The challenge is removed first so it can't be replayed. The rest works on
    # client-supplied bytes, which can make the library raise far more than
    # WebAuthn::Error (bad base64, truncated CBOR, missing keys). All of those
    # mean the same thing here: not verified.
    def verify_webauthn_assertion(credentials, **verify_options)
      challenge = session.delete(:current_challenge)
      assertion = WebAuthn::Credential.from_get(params)
      credential = credentials.find_by(external_id: assertion.id)
      return unless credential

      assertion.verify(challenge, public_key: credential.public_key, sign_count: credential.sign_count, **verify_options)
      credential.update!(sign_count: assertion.sign_count)
      credential
    rescue StandardError => e
      Rails.logger.warn "ActionAuth rejected a WebAuthn assertion: #{e.class}: #{e.message}"
      nil
    end

    # Before filter body for screens that set a new password. Renders +template+
    # with an error when the submitted password is blank or known to be breached.
    def reject_unusable_password(user, template)
      password = string_param(:password)

      if password.blank?
        user.errors.add(:password, :blank)
      elsif (count = pwned_count(password)).positive?
        user.errors.add(:password, "has been pwned #{count} times. Please choose a different password.")
      end

      render template, status: :unprocessable_entity if user.errors.any?
    end

    # Have I Been Pwned being unreachable shouldn't stop anyone from signing up
    # or resetting a password, so an outage counts as "not pwned".
    def pwned_count(password)
      return 0 unless ActionAuth.configuration.pwned_enabled?

      Pwned::Password.new(password).pwned_count
    rescue Pwned::Error => e
      Rails.logger.warn "ActionAuth could not check Have I Been Pwned: #{e.message}"
      0
    end

    def generate_compliant_password
      uppercase = ('A'..'Z').to_a.sample
      lowercase = ('a'..'z').to_a.sample
      digit = ('0'..'9').to_a.sample
      special = %w[! @ # $ % ^ & * ( ) _ + - = [ ] { } | ; : , . < > ?].sample
      random_chars = SecureRandom.alphanumeric(28)
      (random_chars + uppercase + lowercase + digit + special).chars.shuffle.join
    end
  end
end
