# ActionAuth
ActionAuth is an authentication Rails engine crafted to integrate seamlessly
with your Rails application. Optimized for Rails 7.1.0, it employs the most modern authentication
techniques and streamlined token reset processes. Its simplicity and ease of use let you concentrate
on developing your application, while its reliance on ActiveSupport::CurrentAttributes ensures a
user experience akin to that offered by the well-regarded Devise gem.

[![Ruby](https://github.com/kobaltz/action_auth/actions/workflows/test.yml/badge.svg)](https://github.com/kobaltz/action_auth/actions/workflows/test.yml)

## Table of Contents
1. [Introduction](#introduction)
2. [Installation](#installation)
3. [Features](#features)
4. [Usage](#usage)
   - [Routes](#routes)
   - [Helper Methods](#helper-methods)
   - [Restricting and Changing Routes](#restricting-and-changing-routes)
5. [WebAuthn](#webauthn)
6. [Within Your Application](#within-your-application)
7. Customizing
   - [Sign In Page](https://github.com/kobaltz/action_auth/wiki/Overriding-Sign-In-page-view)
7. [License](#license)
8. [Credits](#credits)

## Breaking Changes

With the release of v1.0.0, there are some breaking changes that have been introduced. The
biggest change is that the `ActionAuth::User` model now uses the table name of `users` instead
of `action_auth_users`. This was done to make it easier to integrate with your application
without having to worry about the table name. If you have an existing application that is
using ActionAuth, you will need to rename the table to `users` with a migration like

```ruby
rename_table :action_auth_users, :users
```

Coming from `v0.3.0` to `v1.0.0`, you will need to create a migration to rename the table and foreign keys.

```ruby
class UpgradeActionAuth < ActiveRecord::Migration[7.1]
  def change
    rename_table :action_auth_users, :users

    rename_table :action_auth_sessions, :sessions
    rename_column :sessions, :action_auth_user_id, :user_id

    rename_table :action_auth_webauthn_credentials, :webauthn_credentials
    rename_column :webauthn_credentials, :action_auth_user_id, :user_id
  end
end
```

You will then need to undo the migrations where the foreign keys were added in cases where `foreign_key: true` was
changed to `foreign_key: { to_table: 'action_auth_users' }`. You can do this for each table with a migration like:

```ruby
add_foreign_key :user_settings, :users, column: :user_id unless foreign_key_exists?(:user_settings, :users)
add_foreign_key :profiles, :users, column: :user_id unless foreign_key_exists?(:profiles, :users)
add_foreign_key :nfcs, :users, column: :user_id unless foreign_key_exists?(:nfcs, :users)
```

## Installation
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
  config.webauthn_enabled = true
  config.webauthn_origin = "http://localhost:3000" # or "https://example.com"
  config.webauthn_rp_name = Rails.application.class.to_s.deconstantize
  config.verify_email_on_sign_in = true
  config.magic_link_enabled = true
  config.default_from_email = "from@example.com"
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

✅ - Magic Links

⏳ - OAuth with Google, Facebook, Github, Twitter, etc.

⏳ - Account Deletion

⏳ - Account Lockout

⏳ - Account Suspension

⏳ - Account Impersonation



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
