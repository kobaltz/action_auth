# ActionAuth
ActionAuth is an authentication Rails engine crafted to integrate seamlessly
with your Rails application. Optimized for Rails 7.1.0, it employs the most modern authentication
techniques and streamlined token reset processes. Its simplicity and ease of use let you concentrate
on developing your application, while its reliance on ActiveSupport::CurrentAttributes ensures a
user experience akin to that offered by the well-regarded Devise gem.

[![Ruby](https://github.com/kobaltz/action_auth/actions/workflows/test.yml/badge.svg)](https://github.com/kobaltz/action_auth/actions/workflows/test.yml)

## Installation
Add this line to your application's Gemfile:

```ruby
bundle add action_auth
bin/rails action_auth:install:migrations
```

Modify config/routes.rb to include the following:

```ruby
mount ActionAuth::Engine => 'action_auth'
```

In your view layout

```ruby
<% if user_signed_in? %>
  <li><%= link_to "Sessions", user_sessions_path %></li>
  <li><%= button_to "Sign Out", user_session_path(current_session), method: :delete %></li>
<% else %>
  <li><%= link_to "Sign In", new_user_session_path %></li>
  <li><%= link_to "Sign Up", new_user_registration_path %></li>
<% end %>
```

## Features

These are the planned features for ActionAuth. The ones that are checked off are currently implemented. The ones that are not checked off are planned for future releases.

✅ - Sign Up, Sign In, Sign Out

✅ - Password reset

✅ - Account Email Verification

✅ - Cookie-based sessions

⏳ - Multifactor Authentication

⏳ - Passkeys/Hardware Security Keys

⏳ - Magic Links

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

    Method											Description
    current_user								Returns the currently logged in user
    user_signed_in?							Returns true if the user is logged in
    current_session							Returns the current session

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
        ActionAuth::Session.find_by(id: session_token)&.action_auth_user
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
        session_token.present?
      end
    end

    # config/routes.rb
    constraints AuthenticatedConstraint do
      root to: 'dashboard#index'
    end
    root to: 'welcome#index'


## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Credits

Heavily inspired by [Drifting Ruby #300](https://www.driftingruby.com/episodes/authentication-from-scratch)
and [Authentication Zero](https://github.com/lazaronixon/authentication-zero).
