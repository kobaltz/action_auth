module ActionAuth
  class Magics::RequestsController < ApplicationController
    rate_limit to: 5,
      within: 1.minute,
      only: :create,
      name: "magic-link-throttle",
      with: -> { redirect_to new_magics_requests_path, alert: "Too many requests. Try again later." }

    before_action :require_magic_link_migration, only: :create

    def new
    end

    def create
      user = User.find_or_initialize_by(email: string_param(:email))

      if user.new_record?
        user.password = user.password_confirmation = generate_compliant_password

        unless user.save
          flash.now[:alert] = user.errors.full_messages.to_sentence
          return render :new, status: :unprocessable_entity
        end
      end

      UserMailer.with(user: user).magic_link.deliver_later

      redirect_to sign_in_path, notice: "Check your email for a magic link."
    end

    private

    # Without the column the email would fail in a background job, after this page
    # had already told the person to check their inbox.
    def require_magic_link_migration
      return if User.column_names.include?("magic_link_used_at")

      raise "ActionAuth magic links need a new migration. Run: bin/rails action_auth:install:migrations db:migrate"
    end
  end
end
