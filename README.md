# ActionAuth
ActionAuth is a Rails engine that provides a simple authentication system for your Rails application.
It uses the latest methods for authentication and handling reset tokens from Rails 7.1.0.
It is designed to be simple and easy to use and allows you to focus on building your application.
The functionality of this gem relies on ActiveSupport::CurrentAttributes the methods are
designed to have a similar experience as Devise.

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
