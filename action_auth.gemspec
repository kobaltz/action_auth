require_relative "lib/action_auth/version"

Gem::Specification.new do |spec|
  spec.name        = "action_auth"
  spec.version     = ActionAuth::VERSION
  spec.authors     = ["Dave Kimura"]
  spec.email       = ["dave@k-innovations.net"]
  spec.homepage    = "https://www.github.com/kobaltz/action_auth"
  spec.summary     = "A simple Rails engine for authorization."
  spec.description = "Using the built in features of Rails, ActionAuth provides a simple way to authorize users to perform actions on your application."
  spec.license     = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://www.github.com/kobaltz/action_auth"
  spec.metadata["changelog_uri"] = "https://www.github.com/kobaltz/action_auth/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "bcrypt", "~> 3.1.0"
end
