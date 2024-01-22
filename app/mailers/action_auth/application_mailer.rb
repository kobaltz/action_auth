module ActionAuth
  class ApplicationMailer < ActionMailer::Base
    default from: ActionAuth.configuration.default_from_email
    layout "mailer"
  end
end
