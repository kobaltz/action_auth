# ActionAuth
This is a placeholder for the ActionAuth gem.  It is not yet ready for use.

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

## Usage

### Routes

Within your application, you'll have access to these routes. They have been styled to be consistent with Devise.

    Method	                    Verb	  Params	Description
    user_sessions_path	        GET		          Device session management
    user_session_path	          DELETE	[:id]	  Log Out
    new_user_session_path	      GET		          Log in
    new_user_registration_path	GET		          Sign Up

### Helper Methods

    Method	                    Description
    current_user	              Returns the currently logged in user
    user_signed_in?	            Returns true if the user is logged in
    current_session	              Returns the current session


## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
