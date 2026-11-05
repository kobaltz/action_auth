# bin/rails loads this before anything else, because coverage has to be running
# when the gem is required or everything in lib/ reports as untested.
unless ENV["ACTION_AUTH_NO_COVERAGE"]
  require "simplecov"

  SimpleCov.start "rails" do
    enable_coverage :branch
    skip "/test/"
    # The gemspec requires this file before coverage can start.
    skip "lib/action_auth/version.rb"
    # Only meaningful on a full run, which is what CI does.
    minimum_coverage line: 98, branch: 90 if ENV["CI"]
  end
end
