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
10. [OAuth](#oauth)
11. [Account Lockout](#account-lockout)
12. [Account Suspension](#account-suspension)
13. [Account Deletion](#account-deletion)
14. [WebAuthn](#webauthn)
15. [Within Your Application](#within-your-application)
16. [Customizing](#customizing)
17. [License](#license)
18. [Credits](#credits)


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

  # On by default. See "Account Lockout" and "Account Suspension" below
  config.account_lockout_enabled = true
  config.account_lockout_max_attempts = 10
  config.account_lockout_duration = 30.minutes
  config.account_suspension_enabled = true

  # Needs the omniauth gems. See "OAuth" below
  config.oauth_provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: "user:email"

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
| `account_lockout_enabled` | After 1.8.9 | `true` | Turns on [Account Lockout](#account-lockout). Does nothing until the new migration has run. |
| `account_lockout_max_attempts` | After 1.8.9 | `10` | How many failures in a row lock an account. |
| `account_lockout_duration` | After 1.8.9 | `30.minutes` | How long a lock lasts. `nil` keeps it until it's lifted. |
| `account_suspension_enabled` | After 1.8.9 | `true` | Turns on [Account Suspension](#account-suspension). Nobody is suspended unless your app says so. |
| `oauth_provider` | After 1.8.9 | None | Adds a provider for [OAuth](#oauth). Nothing changes until you add one. Set it in the `ActionAuth.configure` block, not in `after_initialize`. |
| `oauth_enabled` | After 1.8.9 | `defined?(OmniAuth)` | Turns [OAuth](#oauth) off even with providers configured. |
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
- **There are new migrations**, which add columns to `users` and a new `action_auth_connected_accounts` table. Run
  them as part of your deploy, before the new code takes requests. Until they have run, requesting a magic link
  raises an error that tells you to run them. Everything else keeps working, but account lockout and suspension do
  nothing yet.
- **Accounts now lock after 10 failed sign ins in a row**, for 30 minutes, and their owner is sent an email. See
  [Account Lockout](#account-lockout) to change this or turn it off. If your tests fail a sign in that many times
  for one user, they'll need `config.account_lockout_enabled = false`.
- **The first magic link on an unverified account replaces its password**, and ends its other sessions. See
  [Magic Links](#magic-links) for why. If you run with `verify_email_on_sign_in = false`, expect it to reach most of your
  password users, because nothing else verifies them. The link's "Sign in" page warns them first, and they can use Reset
  Password afterwards.
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

✅ - OAuth with Google, Facebook, Github, Twitter, etc.

✅ - SMS Authentication

✅ - Have I Been Pwned Integration

✅ - Account Deletion

✅ - Password Complexity Validation

✅ - Rate Limiting

✅ - Session Timeout

✅ - HTTPS-only cookies in production

✅ - Account Lockout

✅ - Account Suspension

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

### Account Protection
- [Account lockout](#account-lockout) after repeated failed passwords or SMS codes. It's stored in the database, so it
  holds even without a working cache, and doesn't reveal who has an account.
- [Account suspension](#account-suspension) blocks every way of signing in and ends existing sessions.

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

The first time a link is used on an account whose email isn't verified, it also replaces the password, ends every
session on the account and removes its connected OAuth accounts. Until then nobody has shown that the address is
theirs. Anyone can sign up with someone else's address, or change their own account to it, and this stops them from
keeping access once the address's real owner starts using the account. The page with the "Sign in" button says this
first, and the person can use Reset Password afterwards to choose a new password.

Accounts that are already verified aren't affected. Security keys are kept and are still asked for, because removing them
would let someone holding only the inbox get past a second factor. If someone else's key is on the account, that
means its owner can't get past that step.

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

## OAuth

OAuth lets people sign in with an account they have on another site, such as Google, Facebook, GitHub or X. It's built on
[OmniAuth](https://github.com/omniauth/omniauth), so any OmniAuth strategy works.

Like WebAuthn, this is opt in. The gems aren't dependencies of ActionAuth, so apps that don't want this don't carry them,
and nothing changes until you add a provider. If your app already uses OmniAuth for something else, it's left alone.

#### Add the gems

```bash
bundle add omniauth omniauth-rails_csrf_protection
```

Then add a gem for each provider you want.

| Provider | Gem | Name for `oauth_provider` |
| --- | --- | --- |
| Google | `omniauth-google-oauth2` | `:google_oauth2` |
| GitHub | `omniauth-github` | `:github` |
| Facebook | `omniauth-facebook` | `:facebook` |
| X (Twitter) | `omniauth-twitter2` | `:twitter2` |

`omniauth-rails_csrf_protection` isn't optional. Without it every sign in fails, because OmniAuth's own CSRF check
doesn't understand the tokens Rails puts in forms.

#### Run the migration

```bash
bin/rails action_auth:install:migrations
bin/rails db:migrate
```

#### Add your providers

`oauth_provider` takes the same arguments as OmniAuth's `provider`. Set these in the `ActionAuth.configure` block, not in
`after_initialize`, because the routes depend on them.

```ruby
# config/initializers/action_auth.rb
ActionAuth.configure do |config|
  config.oauth_provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"]
  config.oauth_provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], scope: "user:email"
  config.oauth_provider :facebook, ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_APP_SECRET"]
  config.oauth_provider :twitter2, ENV["TWITTER_CLIENT_ID"], ENV["TWITTER_CLIENT_SECRET"],
    scope: "tweet.read users.read",
    callback_url: "https://example.com/action_auth/auth/twitter2/callback"
end

# Callback URLs otherwise come from the request's Host header, which can be forged.
OmniAuth.config.full_host = "https://example.com"
```

- GitHub needs `scope: "user:email"` to see the address of someone who keeps theirs private.
- X needs a `scope`, and `callback_url` too, unless ActionAuth is mounted at `/`. `omniauth-twitter2` otherwise adds the
  mount path twice, and X refuses the sign in.
- The buttons say "Continue with" and the provider's name. To change that name, add `label: "Work Account"`.

Each provider needs to know the callback URL, which is your mount path, then `auth`, the name, and `callback`. For example,
`https://example.com/action_auth/auth/github/callback`.

Providers appear on the sign in and sign up screens, and in a new section of the management screen at `user_sessions_path`.

#### What happens when someone signs in

| Situation | Result |
| --- | --- |
| They've connected this account before | They're signed in, whatever email address the provider now reports. A security key is still required if they have one. |
| They're new here | They get a new account using the provider's email address. It has a random password, which they can reset if they want one. |
| They're new here, and the provider doesn't share an email address, or says it's unverified | They get a new account with a placeholder address, as with SMS. They can only sign in through the provider. X usually works like this. |
| Their email address matches an existing account | They **aren't** signed in. They're told to sign in another way, then connect the provider from the management screen. |
| They're already signed in | The provider is connected to the account they're signed in to. |
| The provider is connected to someone else | They're told, and nothing changes. |

An email address match never signs anyone in, because that would rely on every provider having verified the address, and
on nobody having signed up here with an address they don't own. For the same reason, only add providers that verify
email addresses, or that don't share them. New accounts take the address the provider gives.

Disconnecting from the management screen works unless it's the only way left to sign in to that account. Only the
provider's name for the account is stored, not its access tokens. If you need those, for example to call the provider's
API, that's currently something your app has to do itself.

#### Your own views

If you've copied `sessions/new` or `registrations/new` into your app, add the buttons where you want them.

```erb
<%= render "action_auth/shared/oauth_buttons" %>
```

To style them yourself, use `action_auth_oauth_providers`. These have to be POST requests, and Turbo has to stay out of
them, because the response redirects to another site.

```erb
<% action_auth_oauth_providers.each do |label, path| %>
  <%= button_to "Continue with #{label}", path, form: { data: { turbo: false } }, class: "btn" %>
<% end %>
```

Similarly, add `render "action_auth/sessions/connected_accounts"` to a copied `sessions/index`.

#### Good to know

- If your app has a Content Security Policy that sets `form-action`, it needs to allow your providers' sites, or browsers
  will block the redirect after the button is pressed.
- In development, OmniAuth raises an error when something goes wrong at the provider, such as pressing cancel on its page.
  Elsewhere it goes back to the sign in screen with a message. See `OmniAuth.config.failure_raise_out_environments`.
- To test your app without a real provider, use [OmniAuth's test mode](https://github.com/omniauth/omniauth/wiki/Integration-Testing).

## Account Lockout

Account lockout is on by default. After 10 failed passwords or SMS codes in a row, an account is locked for 30 minutes.

```ruby
ActionAuth.configure do |config|
  config.account_lockout_enabled = true
  config.account_lockout_max_attempts = 10
  config.account_lockout_duration = 30.minutes # nil keeps it locked until it's lifted
end
```

While an account is locked, the sign in form gives the same answer it gives to a wrong password, even if the password is
right. Saying "locked" only when the password is right would let someone carry on guessing, and saying it to everyone would
reveal who has an account. So that they aren't left wondering, the account's owner is sent an email when the lock
starts, with a link to reset their password.

A lock ends by itself, or as soon as they reset their password or sign in another way. Signing in also restarts the count.

Only things that can be guessed are locked out. A magic link, passkey or connected OAuth account still works, and devices
that are already signed in stay signed in. Without this, anyone who knew an email address could keep its owner out by
failing on purpose. They can still lock password sign in that way, which is why locks are temporary. It does mean that an
account that only has SMS, with no other way in, has to wait.

From your app, you can use `user.account_locked?` and `user.unlock_account!`. To change the email, generate the
`user_mailer` views. If the email can't be sent, the problem is logged, and the sign in form still answers as usual.

This adds to [rate limiting](#rate-limiting), which is per client and depends on your cache. Lockout is per account and
depends on your database.

## Account Suspension

Account suspension is on by default, but nothing happens until your app suspends someone. ActionAuth has no admin screen,
since it doesn't know who your admins are, so call this from your own, behind your own authorization.

```ruby
user.suspend_account!   # Blocks every way of signing in, and signs them out everywhere
user.account_suspended?
user.unsuspend_account!
```

A suspended account can't sign in with a password, magic link, SMS code, passkey, security key or OAuth, and can't reset its
password. They're only told it's suspended after proving who they are, such as with the right password. Everyone else gets
the usual answers, so this doesn't reveal who has been suspended, and forms that would send something just don't send it.

`suspend_account!` raises an error if it can't take effect, such as before the migration has run or with
`config.account_suspension_enabled = false`. Setting `account_suspended_at` directly also blocks the account and ends its
sessions on their next request, but use `suspend_account!`, so that a route constraint that reads sessions itself, like the
one [above](#restricting-and-changing-routes-with-constraints), sees it straight away.

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
message. An account that signed in with a magic link or OAuth has a random password, so it has to reset the password
first. An account created through SMS, or through an OAuth provider that didn't share an email address, has no password or
email to reset, so instead it can delete itself within 10 minutes of signing in again. It doesn't need the password field.

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
    action_auth_oauth_providers		[label, path] pairs for OAuth providers, which need a button rather than a link. See OAuth
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
    shared/_oauth_buttons.html.erb		OAuth buttons on the sign in and sign up screens
    sessions/_sessions.html.erb		List of signed in devices on the management screen
    sessions/_security_keys.html.erb		List of security keys on the management screen
    sessions/_connected_accounts.html.erb	List of connected OAuth accounts on the management screen
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
