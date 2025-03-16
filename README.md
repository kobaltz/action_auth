# ActionAuth
ActionAuth is an authentication Rails engine crafted to integrate seamlessly
with your Rails application. Optimized for Rails 7.2.0, it employs the most modern authentication
techniques and streamlined token reset processes. Its simplicity and ease of use let you concentrate
on developing your application, while its reliance on ActiveSupport::CurrentAttributes ensures a
user experience akin to that offered by the well-regarded Devise gem.

[![Ruby](https://github.com/kobaltz/action_auth/actions/workflows/test.yml/badge.svg)](https://github.com/kobaltz/action_auth/actions/workflows/test.yml)

## Table of Contents
1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Features](#features)
4. [Security Features](#security-features)
   - [Password Security](#password-security)
   - [Session Security](#session-security)
   - [Rate Limiting](#rate-limiting)
   - [Multi-Factor Authentication](#multi-factor-authentication)
5. [Usage](#usage)
   - [Routes](#routes)
   - [Helper Methods](#helper-methods)
   - [Restricting and Changing Routes](#restricting-and-changing-routes)
6. [Have I Been Pwned](#have-i-been-pwned)
7. [Magic Links](#magic-links)
8. [SMS Authentication](#sms-authentication)
9. [Account Deletion](#account-deletion)
10. [WebAuthn](#webauthn)
11. [Within Your Application](#within-your-application)
12. Customizing
   - [Sign In Page](https://github.com/kobaltz/action_auth/wiki/Overriding-Sign-In-page-view)
13. [License](#license)
14. [Credits](#credits)


## Minimum Requirements

- Ruby 3.3.0 or later recommended
- Rails 7.2.0 or later **required**

## Installation

### Automatic Installation

Add this line to your application's Gemfile:

```ruby
bundle add action_auth
```

Then run the rake task to copy over the migrations, config and routes.

```bash
bin/rails action_auth:install
```

### Manual Installation

Add this line to your application's Gemfile:

```ruby
bundle add action_auth
bin/rails action_auth:install:migrations
```

Modify config/routes.rb to include the following (note that the path can be anything you want):

```ruby
mount ActionAuth::Engine => 'action_auth'
```

In your view layout

```ruby
<% if user_signed_in? %>
  <li><%= link_to "Security", user_sessions_path %></li>
  <li><%= button_to "Sign Out", user_session_path(current_session), method: :delete %></li>
<% else %>
  <li><%= link_to "Sign In", new_user_session_path %></li>
  <li><%= link_to "Sign Up", new_user_registration_path %></li>
<% end %>
```

If you're using something like importmaps and plain css, then you may need to add the lines below to your `app/assets/config/manifest.js` file.

```javascript
//= link action_auth/application.css
//= link action_auth/application.js
```

See [WebAuthn](#webauthn) for additional configuration steps if you want to enable WebAuthn.
In your `config/initializers/action_auth.rb` file, you can add the following configuration
settings.

```ruby
ActionAuth.configure do |config|
  config.allow_user_deletion = true
  config.default_from_email = "from@example.com"
  config.magic_link_enabled = true
  config.passkey_only = true # Allows sign in with only a passkey
  config.pwned_enabled = true # defined?(Pwned)
  config.password_complexity_check = true # Requires complex passwords
  config.session_timeout = 2.weeks # Session expires after this period of inactivity
  config.sms_auth_enabled = false
  config.verify_email_on_sign_in = true
  config.webauthn_enabled = true # defined?(WebAuthn)
  config.webauthn_origin = "http://localhost:3000" # or "https://example.com"
  config.webauthn_rp_name = Rails.application.class.to_s.deconstantize

  config.insert_cookie_domain = false
end

Rails.application.config.after_initialize do
  ActionAuth.configure do |config|
    config.sms_send_class = SmsSender
  end
end
```

## Features

These are the planned features for ActionAuth. The ones that are checked off are currently implemented. The ones that are not checked off are planned for future releases.

✅ - Sign Up, Sign In, Sign Out

✅ - Password reset

✅ - Account Email Verification

✅ - Cookie-based sessions

✅ - Device Session Management

✅ - Multifactor Authentication (through Passkeys)

✅ - Passkeys/Hardware Security Keys

✅ - Passkeys sign in without email/password

✅ - Magic Links

⏳ - OAuth with Google, Facebook, Github, Twitter, etc.

✅ - SMS Authentication

✅ - Have I Been Pwned Integration

✅ - Account Deletion

✅ - Password Complexity Validation

✅ - Rate Limiting

✅ - Session Timeout

✅ - HTTPS-only cookies in production

⏳ - Account Lockout

⏳ - Account Suspension

⏳ - Account Impersonation

## Security Features

ActionAuth comes with a robust set of security features designed to protect user accounts and data:

### Password Security
- Minimum password length of 12 characters
- Password complexity validation requiring uppercase, lowercase, numbers, and special characters
- Integration with Have I Been Pwned to check for compromised passwords
- Password complexity validation can be configured to suit your application's needs

### Session Security
- Session timeout with configurable duration (default: 2 weeks)
- Automatic session invalidation on password change
- HTTPS-only cookies in production environments
- HttpOnly flag on cookies to prevent JavaScript access
- SameSite=Lax attribute to prevent CSRF attacks
- IP address and user agent tracking to detect session hijacking
- Suspicious activity detection for changed IP/user agent

### Rate Limiting
- Protection against brute force attacks on login
- Rate limiting on registration attempts
- Rate limiting on password reset attempts
- Rate limiting on WebAuthn authentication

### Multi-Factor Authentication
- Support for WebAuthn/passkeys as a second factor
- Modern security key and biometric authentication support
- Magic link authentication as an alternative authentication method

### Configuration Options
```ruby
ActionAuth.configure do |config|
  # Enable password complexity validation
  config.password_complexity_check = true

  # Set session timeout (defaults to 2 weeks)
  config.session_timeout = 2.weeks

  # Other settings as needed...
end
```

## Usage

### Routes

Within your application, you'll have access to these routes. They have been styled to be consistent with Devise.

    Method				Verb		Params	Description
    user_sessions_path		GET			Device session management
    user_session_path		DELETE		[:id]	Log Out
    new_user_session_path		GET			Log in
    new_user_registration_path	GET			Sign Up
    edit_password_path		GET			Change Password
    password_path			PATCH			Update Password

### Helper Methods

    Method			Description
    current_user		Returns the currently logged in user
    user_signed_in?		Returns true if the user is logged in
    current_session		Returns the current session

### Restricting and Changing Routes with Constraints

Sometimes, there could be some routes that you would want to prevent access to unless the
user is an admin. These routes could be for managing users, or other sensitive data. You
can create a constraint to restrict access to these routes.

    # app/constraints/admin_constraint.rb

    class AdminConstraint
      def self.matches?(request)
        user = current_user(request)
        user && user.admin?
      end

      def self.current_user(request)
         session_token = request.cookie_jar.signed[:session_token]
         session = ActionAuth::Session.find_by(id: session_token)
         return nil unless session.present?
         session.action_auth_user&.becomes(User)
      end
    end

    # config/routes.rb

    constraints AdminConstraint do
      mount GoodJob::Engine => 'good_job'
    end

Other times, you may want to have a different kind of view for a user that is logged in
versus a user that is not logged in.

    # app/constraints/authenticated_constraint.rb
    class AuthenticatedConstraint
      def self.matches?(request)
        session_token = request.cookie_jar.signed[:session_token]
        ActionAuth::Session.exists?(session_token)
      end
    end

    # config/routes.rb
    constraints AuthenticatedConstraint do
      root to: 'dashboard#index'
    end
    root to: 'welcome#index'

## Have I Been Pwned

[Have I Been Pwned](https://haveibeenpwned.com/) is a way that youre able to check if a password has been compromised in a data breach. This is a great way to ensure that your users are using secure passwords.

Add the `pwned` gem to your Gemfile. That's all you'll have to do to enable this functionality.

```ruby
bundle add pwned
```

## Magic Links

Magic Links are a way to authenticate a user without requiring a password. This is done by sending
an email to the user with a link that will log them in. This is a great way to allow users to log in
without having to remember a password. This is especially useful for users who may not have a password
manager or have a hard time remembering passwords.

## SMS Authentication

SMS Authentication is disabled by default. The purpose of this is to allow users to authenticate
with a phone number. This is useful and specific to applications that may require a phone number
instead of an email address for authentication. The basic workflow for this is to register a phone
number, and then send a code to the phone number. The user will then enter the code to authenticate.

No password or email is required for this. I do not recommend enabling this feature for most applications.

You must set up your own SMS Provider. This is not included in the gem. You will need to configure the
`sms_send_class` to send the SMS code. This will expect a class method called `send_code` that will take in the parameters
`phone_number` and `code`.

```ruby
require 'twilio-ruby'

class SmsSender
  def self.send_code(phone_number, code)
    account_sid = ENV['TWILIO_ACCOUNT_SID']
    auth_token = ENV['TWILIO_AUTH_TOKEN']
    from_number = ENV['TWILIO_PHONE_NUMBER']

    client = Twilio::REST::Client.new(account_sid, auth_token)

    client.messages.create(
      from: from_number,
      to: phone_number,
      body: "Your verification code is #{code}"
    )
  end
end
```

Since this file could live in the `app/models` or elsewhere, we will need to set its configuration after the Rails
application has been loaded. This can be done in an initializer.

```ruby
Rails.application.config.after_initialize do
  ActionAuth.configure do |config|
    config.sms_send_class = SmsSender
  end
end
```

## Account Deletion

Account deletion is a feature that is enabled by default. When a user deletes their account, the account
is marked as deleted and the user is logged out. The user will no longer be able to log in with their
email and password. The user will need to create a new account if they wish to continue using the application.

Here's an example of how you may want to add a delete account button to your application. Obviously, you
will want to style this to fit your application and have some kind of confirmation dialog.

```
<p>
  Unhappy with the service?
  <%= button_to "Delete Account", action_auth.users_path, method: :delete %>
</p>
```

## WebAuthn

ActionAuth's approach for WebAuthn is simplicity. It is used as a multifactor authentication step,
so users will still need to register their email address and password. Once the user is registered,
they can add a Passkey to their account. The Passkey could be an iCloud Keychain, a hardware security
key like a Yubikey, or a mobile device. If enabled and configured, the user will be prompted to use
their Passkey after they log in.

#### Configuration

The migrations are already copied over to your application when you run
`bin/rails action_auth:install:migrations`. There are only two steps that you have to take to enable
WebAuthn for your application.

The reason why you need to add the gem is because it's not added to the gemspec of ActionAuth. This is
intentional as not all users will want to add this functionality. This will help minimize
the number of gems that your application relies on unless if they are features that you want to use.

#### Add the gem

```
bundle add webauthn
```

### Configure the WebAuthn settings

**Note:** that the origin name does not have a trailing / or a port number.

```
ActionAuth.configure do |config|
  config.webauthn_enabled = true
  config.webauthn_origin = "http://localhost:3000" # or "https://example.com"
  config.webauthn_rp_name = Rails.application.class.to_s.deconstantize
  config.verify_email_on_sign_in = true
  config.default_from_email = "from@example.com"
end
```

### Demo

Here's a view of the experience with WebAuthn

![action_auth](https://github.com/kobaltz/action_auth/assets/635114/fa88d83c-5af5-471b-a094-ec9785ea2f87)

## Within Your Application

It can be cumbersome to have to reference ActionAuth::User within the application as well as in the
relationships between models. Luckily, we can use ActiveSupport::CurrentAttributes to make this
process easier as well as inheritance of our models.

#### Setting up the User model

```ruby
# app/models/user.rb
class User < ActionAuth::User
  has_many :posts, dependent: :destroy
end
```

#### Setting up the Current model

We can set the user to become a User record instead of an ActionAuth::User record. This will then allow `Current.user.posts` to work.

```ruby
# app/models/current.rb
class Current < ActiveSupport::CurrentAttributes
  def user
    return unless ActionAuth::Current.user
    ActionAuth::Current.user&.becomes(User)
  end
end
```

#### Generating an association

We are using `user:belongs_to` instead of `action_auth_user:belongs_to`.

```bash
bin/rails g scaffold posts user:belongs_to title
```

And the post model doesn't need anything special to ActionAuth.

```ruby
# app/models/post.rb
class Post < ApplicationRecord
  belongs_to :user
end
```

#### Using the Current model

Now, you'll be able to do things like `Current.user` and `Current.user.posts` within your application. However, I recommend that you still use
the helpers around `user_signed_in?` to verify that the `ActionAuth::Current.user` is not nil (or nil if they are signed out). This will help ensure that any thread safety issues are avoided.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Credits

❤️ Heavily inspired by [Drifting Ruby #300](https://www.driftingruby.com/episodes/authentication-from-scratch)
and [Authentication Zero](https://github.com/lazaronixon/authentication-zero) and
[cedarcode](https://www.cedarcode.com/).
