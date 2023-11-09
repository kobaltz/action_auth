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

## Usage

### Routes

Within your application, you'll have access to these routes. They have been styled to be consistent with Devise.

    Method	                    Verb	  Params	Description
    user_sessions_path	        GET		            Device session management
    user_session_path	        DELETE	  [:id]     Log Out
    new_user_session_path	    GET		            Log in
    new_user_registration_path	GET		            Sign Up
    edit_password_path          GET		            Change Password
    password_path               PATCH               Update Password

### Helper Methods

    Method	                    Description
    current_user	            Returns the currently logged in user
    user_signed_in?	            Returns true if the user is logged in
    current_session	            Returns the current session

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


## Credits

Heavily inspired by [Drifting Ruby #300](https://www.driftingruby.com/episodes/authentication-from-scratch)
and [Authentication Zero](https://github.com/lazaronixon/authentication-zero).
