source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

# Specify your gem's dependencies in action_auth.gemspec.
gemspec

gem "puma"
gem "sqlite3"
gem "sprockets-rails"

group :development do
  gem "letter_opener"
end

group :test do
  gem "simplecov", require: false
  gem "minitest-stub_any_instance"
  gem "minitest", "< 6.0"
end

# Add these gems for WebAuthn support
gem "webauthn"

# Add these gems for pwened password support
gem "pwned"

gem "twilio-ruby"
