module ActionAuth
  # Where someone comes back to after approving a sign in on another site. By the time
  # create runs, the OmniAuth strategy has checked that this browser started the flow.
  class ProviderCallbacksController < ApplicationController
    FAILED = "We couldn't connect to that provider. Please try again.".freeze

    # Some providers POST the callback from their own site, so it can't carry a token
    # from ours. Nothing happens here without omniauth.auth, which only the strategy can
    # set, and only after it has checked the OAuth state.
    skip_forgery_protection only: :create

    rate_limit to: 10,
      within: 1.minute,
      only: :create,
      name: "oauth-callback-throttle",
      with: -> { redirect_to sign_in_path, alert: "Too many attempts. Try again later." }

    before_action :require_connected_accounts_migration, only: :create
    before_action :require_valid_response, only: :create

    def create
      connected_account = ConnectedAccount.find_by(provider: provider_key, uid: uid)

      if user_signed_in?
        connect(connected_account)
      elsif connected_account
        complete_sign_in(connected_account.user, notice: "Signed in successfully")
      else
        sign_up
      end
    end

    # What's sent in the message parameter can't be trusted, so it's never displayed.
    def failure
      if params[:message] == "authenticity_error"
        Rails.logger.error "ActionAuth OAuth needs the omniauth-rails_csrf_protection gem, or the form was missing its token"
      end

      redirect_to user_signed_in? ? sessions_path : sign_in_path, alert: FAILED, status: :see_other
    end

    private

    def auth
      request.env["omniauth.auth"]
    end

    def provider_key
      auth.provider.to_s
    end

    def uid
      auth.uid.to_s
    end

    def provider_label
      ActionAuth.configuration.oauth_providers.find { |oauth| oauth.key == provider_key }.label
    end

    # An app can also run OmniAuth for its own purposes, and an identity from one of
    # those providers isn't one that ActionAuth was asked to trust for sign in.
    def require_valid_response
      return if auth && uid.present? && ActionAuth.configuration.oauth_providers.any? { |oauth| oauth.key == provider_key }

      failure
    end

    def require_connected_accounts_migration
      return if ConnectedAccount.table_exists?

      raise "ActionAuth OAuth needs a new migration. Run: bin/rails action_auth:install:migrations db:migrate"
    end

    def connect(connected_account)
      if connected_account&.user_id == Current.user.id
        redirect_to sessions_path, notice: "#{provider_label} is already connected to your account."
      elsif connected_account.nil? && create_connected_account(Current.user)
        redirect_to sessions_path, notice: "#{provider_label} has been connected to your account."
      else
        redirect_to sessions_path, alert: "That #{provider_label} account is connected to a different account."
      end
    end

    def create_connected_account(user)
      user.connected_accounts.create!(provider: provider_key, uid: uid, display_name: display_name)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      false
    end

    # Only for showing on the management screen. Cut to fit, because a 255 character
    # column on MySQL would refuse a long one and fail the sign in over nothing.
    def display_name
      info = auth.info

      (info&.email.presence || info&.nickname.presence || info&.name.presence)&.first(255)
    end

    # Having the same email address isn't enough to sign in to an existing account.
    # That would rely on every provider having verified it, and on nobody having signed
    # up here with an address they don't own and kept the password. Signing in first
    # proves it's the same person, and takes one step.
    def sign_up
      email = provider_email

      if email && User.exists?(email: email)
        return redirect_to(sign_in_path, alert: "There's already an account with that email address. " \
          "Sign in, then connect #{provider_label} from your account page.")
      end

      user = create_user(email)

      if user
        complete_sign_in(user, notice: "Welcome! You have signed up successfully")
      else
        redirect_to sign_in_path, alert: FAILED
      end
    end

    # Providers may not share an address, or may flag it as unverified, in which case
    # it says nothing about who this is. Those accounts get a placeholder, as SMS does.
    def provider_email
      info = auth.info
      email = info&.email.to_s.strip
      flagged = ActiveModel::Type::Boolean.new.cast(info&.email_verified) == false

      email if !flagged && email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def create_user(email)
      password = generate_compliant_password

      User.transaction do
        User.create!(
          email: email || "#{SecureRandom.hex(32)}#{User::OAUTH_EMAIL_SUFFIX}",
          password: password,
          password_confirmation: password,
          verified: true
        ).tap do |user|
          user.connected_accounts.create!(provider: provider_key, uid: uid, display_name: display_name)
        end
      end
    # Someone else got there first, such as a double click on the provider's page.
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end
  end
end
