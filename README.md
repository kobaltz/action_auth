# ActionAuth
ActionAuth is an authentication Rails engine crafted to integrate seamlessly
with your Rails application. It supports Rails 7.2 and later, and employs the most modern authentication
techniques and streamlined token reset processes. Its simplicity and ease of use let you concentrate
on developing your application, while its reliance on ActiveSupport::CurrentAttributes ensures a
user experience akin to that offered by the well-regarded Devise gem.

[![Ruby](https://github.com/kobaltz/action_auth/actions/workflows/test.yml/badge.svg)](https://github.com/kobaltz/action_auth/actions/workflows/test.yml)

## Table of Contents
1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Upgrading](#upgrading)
4. [Features](#features)
5. [Security Features](#security-features)
   - [Password Security](#password-security)
   - [Session Security](#session-security)
   - [Rate Limiting](#rate-limiting)
   - [Multi-Factor Authentication](#multi-factor-authentication)
6. [Usage](#usage)
   - [Routes](#routes)
   - [Helper Methods](#helper-methods)
   - [Restricting and Changing Routes](#restricting-and-changing-routes)
7. [Have I Been Pwned](#have-i-been-pwned)
8. [Magic Links](#magic-links)
9. [SMS Authentication](#sms-authentication)
10. [Account Deletion](#account-deletion)
11. [WebAuthn](#webauthn)
12. [Within Your Application](#within-your-application)
13. [Customizing](#customizing)
14. [License](#license)
15. [Credits](#credits)


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

  # See "Customizing" below
  config.layout = "application" # Use your app's layout
  config.parent_controller = "ApplicationController" # Lets your layout use your app's helpers
  config.after_sign_in_path = "/dashboard" # or -> { main_app.dashboard_path }
  config.after_sign_out_path = "/"
end

Rails.application.config.after_initialize do
  ActionAuth.configure do |config|
    config.sms_send_class = SmsSender
  end
end
```

## Upgrading

### Every upgrade

Update the gem, then copy and run any new migrations:

```bash
bundle update action_auth
bin/rails action_auth:install:migrations
bin/rails db:migrate
```

`action_auth:install:migrations` only copies migrations your app doesn't have yet. It's safe to run on every
upgrade, and prints nothing when there's nothing new.

You don't need to run `bin/rails action_auth:install` again, though it's safe to. It leaves your initializer and
your `mount` line alone.

Then check the [changelog](CHANGELOG.md) for anything else that needs a change in your app.

### New settings

Upgrading never changes `config/initializers/action_auth.rb`, so that file won't list settings added after you
installed. Every setting has a default, which means your app keeps working without them. Only add one if you
want something other than its default:

```ruby
# config/initializers/action_auth.rb
ActionAuth.configure do |config|
  config.layout = "application"
  config.session_timeout = 1.week
end
```

If your file is still all comments, as `action_auth:install` generates it, also uncomment the
`ActionAuth.configure do |config|` and `end` lines, or your settings won't take effect.

These settings were added in 1.7.0 or later:

| Setting | Added in | Default | What it does |
| --- | --- | --- | --- |
| `layout` | After 1.8.9 | `nil` (ActionAuth's layout) | The layout for ActionAuth's screens. See [Customizing](#customizing). |
| `parent_controller` | After 1.8.9 | `"ActionController::Base"` | What ActionAuth's controllers inherit from. Use `"ApplicationController"` if your layout calls your app's helpers. Set it in the `ActionAuth.configure` block, not in `after_initialize`. |
| `after_sign_in_path` | After 1.8.9 | `nil` (your root path) | Where people go after signing in. A path or a Proc. |
| `after_sign_out_path` | After 1.8.9 | `nil` (your root path) | Where people go after signing out. A path or a Proc. |
| `password_complexity_check` | 1.8.0 | `true` | Requires new passwords to mix upper and lower case letters, numbers and special characters. |
| `session_timeout` | 1.8.0 | `2.weeks` | How long a session can go unused before it expires. `nil` turns this off. |
| `insert_cookie_domain` | 1.7.1 | `false` | Shares the session cookie across subdomains. |
| `sms_auth_enabled` | 1.7.0 | `false` | Turns on [SMS Authentication](#sms-authentication). |
| `sms_send_class` | 1.7.0 | `nil` | The class that sends SMS codes. Set it in an `after_initialize` block. |

### From 1.8.9 or earlier

No new settings are required, but these may need something from you:

- **Rails 7.2 or later is required.**
- **There's a new migration**, which adds `users.magic_link_used_at`. Run it as part of your deploy, before the
  new code takes requests. Until it has run, requesting a magic link raises an error that tells you to run it.
- **Your tests may need a setting.** Password complexity is no longer skipped in the test environment. If your
  tests create users with simple passwords, add this to your initializer, or use stronger passwords:

  ```ruby
  config.password_complexity_check = !Rails.env.test?
  ```

- **Your delete account button may need a password field.** A `button_to` copied from an earlier version of this
  README no longer deletes the account. See [Account Deletion](#account-deletion) for a form to use.
- **Rate limits need a working cache.** They use `config.cache_store`, and `:null_store` turns them off. With
  several server processes, use a shared store such as Solid Cache or Redis.

If you've copied views or a layout into your app, or have your own WebAuthn JavaScript, the
[changelog](CHANGELOG.md#upgrading) lists what to change, along with the other changes in this release.

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
- Rate limiting on magic link, SMS and password reset requests, and on SMS code guesses

Rate limits are stored in `config.cache_store`, so `:null_store` turns them off. If you run several
server processes, use a store they share, such as Solid Cache or Redis.

### Multi-Factor Authentication
- Support for WebAuthn/passkeys as a second factor
- Modern security key and biometric authentication support
- Magic link authentication as an alternative authentication method. An account with a security key
  still has to use it after a magic link or an SMS code.

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
    edit_user_password_path		GET			Change Password
    user_password_path		PATCH			Update Password

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
         session.user&.becomes(User)
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

A link expires after 20 minutes and only works once. Using one also uses up any others already sent to that
account. Opening a link shows a page with a "Sign in" button rather than signing in straight away, because
mail scanners and link previews open the links in an email and would otherwise use them up first.

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
and its sessions and security keys are permanently deleted, and the user is logged out. The user will need
to create a new account if they wish to continue using the application.

Deleting an account requires the current password. The management screen at `user_sessions_path` includes a
form for this, so the simplest option is to link there. Here's an example of how you may want to add the form
somewhere else in your application. Obviously, you will want to style this to fit your application.

```
<%= form_with url: action_auth.users_path, method: :delete do |form| %>
  <p>Unhappy with the service?</p>
  <%= form.label :password_challenge, "Current password" %>
  <%= form.password_field :password_challenge, required: true, autocomplete: "current-password" %>
  <%= form.submit "Delete Account" %>
<% end %>
```

If the password is missing or wrong, the account is kept and the user is sent to the management screen with a
message. An account that signed in with a magic link has a random password, so it has to reset the password
first. An account created through SMS has no password or email to reset, so instead it can delete itself within
10 minutes of signing in with a new SMS code. It doesn't need the password field.

## WebAuthn

ActionAuth's approach for WebAuthn is simplicity. It is used as a multifactor authentication step,
so users will still need to register their email address and password. Once the user is registered,
they can add a Passkey to their account. The Passkey could be an iCloud Keychain, a hardware security
key like a Yubikey, or a mobile device. If enabled and configured, the user will be prompted to use
their Passkey after they log in.

The screens that use WebAuthn load Stimulus and `@github/webauthn-json` from unpkg.com, and no other screen
loads them. If your app has a Content Security Policy, it needs to allow that host on those screens.

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

## Customizing

There are several ways to make ActionAuth's screens your own. Start at the top, and only go as far as you need.

### Use your app's layout

This is one line, and is often all you need.

```ruby
# config/initializers/action_auth.rb
ActionAuth.configure do |config|
  config.layout = "application"
end
```

Your layout's route helpers, like `root_path`, keep working on these screens. If your app has a route with the
same name as one of ActionAuth's, such as `session_path`, ActionAuth's wins here, so use `main_app.session_path`
for yours.

If your layout calls your own helpers, also make ActionAuth's controllers inherit from your `ApplicationController`.

```ruby
ActionAuth.configure do |config|
  config.layout = "application"
  config.parent_controller = "ApplicationController"
end
```

This has to be set in the initializer's `ActionAuth.configure` block, not inside `after_initialize`.

If your `ApplicationController` has `before_action :authenticate_user!`, there's nothing more to do, because
ActionAuth skips it on the screens that have to be public. For any other filter that shouldn't run on these screens,
such as checking for a subscription, use the `action_auth_controller?` predicate.

```ruby
class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  before_action :require_subscription, unless: :action_auth_controller?
end
```

Only a few screens need a different layout? Create one named after the screens, and leave `config.layout` unset. For
example, `app/views/layouts/action_auth/sessions.html.erb` is used for the sign in page and the management screen.
To replace the default layout without changing the setting, create `app/views/layouts/action_auth/application.html.erb`.

### Change the views

Copy the views into your app, then edit them. Your copies take priority over the ones in the gem.

```bash
bin/rails generate action_auth:views                       # Everything
bin/rails generate action_auth:views sessions registrations # Only these
bin/rails generate action_auth:views sessions --layout     # Also the default layout
```

    Scope					Screens
    sessions				Sign in, and the management screen for sessions and security keys
    registrations				Sign up
    passwords				Change password
    identity				Change email, verify email and reset password
    magics					Request and confirm a magic link
    sms_auths				Request and enter an SMS code
    webauthn_credentials			Add a security key
    webauthn_credential_authentications	Use a security key while signing in
    user_mailer				Emails
    shared					Flash messages, form errors and links between screens

Copied views don't pick up fixes from future versions of ActionAuth, so only keep the ones you've changed. Delete the
rest and they'll go back to following the gem.

Inside a view, your app's routes are available as usual, and ActionAuth's helpers are there too.

    Helper					Description
    action_auth_links			[label, path] pairs for the other auth screens, leaving out disabled features and the current page
    after_sign_in_path			Where signing in goes
    after_sign_out_path			Where signing out goes
    current_user, current_session		The signed in user and their session

For example, to style the links between screens without checking which features are on:

```erb
<% action_auth_links.each do |label, path| %>
  <%= link_to label, path, class: "underline" %>
<% end %>
```

See [examples](examples) for some Tailwind CSS versions of these screens.

### Change one piece

If you only want to change part of a screen, override the partial that renders it. Generate the `shared` or `sessions`
scope and delete the files you don't need, or create the file yourself.

    Partial in app/views/action_auth		Used for
    shared/_flash.html.erb			Flash messages
    shared/_errors.html.erb			Form errors
    shared/_links.html.erb			Links between the sign in, sign up and similar screens
    sessions/_sessions.html.erb		List of signed in devices on the management screen
    sessions/_security_keys.html.erb		List of security keys on the management screen
    sessions/_account.html.erb		Change email, change password and delete account

#### Flash messages

Each screen displays its own flash messages, so they appear in any layout. They're removed once displayed, so a layout
that also displays flash won't show them twice. To use your layout's flash instead, make
`app/views/action_auth/shared/_flash.html.erb` an empty file.

#### WebAuthn screens

If you write your own screens for adding or using a security key, keep these parts from the generated views, since the
JavaScript looks for them.

- `<%= action_auth_webauthn_tags %>`, which loads the scripts and URLs they need, in any layout.
- The `id="webauthn_credential_form"` element and its `data-controller` attributes.
- `<%= render "action_auth/shared/webauthn_error" %>`, or any element with `id="webauthn_error"`, to show failures.

### Change where people go

```ruby
ActionAuth.configure do |config|
  config.after_sign_in_path = "/dashboard"
  config.after_sign_out_path = "/"

  # A Proc runs in the controller, so it can use routes and the request
  config.after_sign_in_path = -> { main_app.dashboard_path }
end
```

Both default to your app's root path.

### Change the emails

Generate the `user_mailer` scope to change their content. They use your app's `layouts/mailer` layout, and come from
`config.default_from_email`.

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Credits

❤️ Heavily inspired by [Drifting Ruby #300](https://www.driftingruby.com/episodes/authentication-from-scratch)
and [Authentication Zero](https://github.com/lazaronixon/authentication-zero) and
[cedarcode](https://www.cedarcode.com/).
