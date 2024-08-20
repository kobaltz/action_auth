desc "Installs Configs, Migrations, and Routes for ActionAuth"
namespace :action_auth do
  task :install do
    # Copies to config/initializers/action_auth.rb
    puts "Installing ActionAuth Configs"
    config_file_path = Rails.root.join('config', 'initializers', 'action_auth.rb')
    unless File.exist?(config_file_path)
      File.open(config_file_path, 'w') do |file|
        file.puts <<~RUBY
          # ActionAuth.configure do |config|
          #   config.allow_user_deletion = true
          #   config.default_from_email = "from@example.com"
          #   config.magic_link_enabled = true
          #   config.passkey_only = true # Allows sign in with only a passkey
          #   config.pwned_enabled = true # defined?(Pwned)
          #   config.verify_email_on_sign_in = true
          #   config.webauthn_enabled = true # defined?(WebAuthn)
          #   config.webauthn_origin = "http://localhost:3000" # or "https://example.com"
          #   config.webauthn_rp_name = Rails.application.class.to_s.deconstantize
          # end
        RUBY
      end
      puts "Created config/initializers/action_auth.rb"
    else
      puts "Config file already exists at config/initializers/action_auth.rb"
    end

    # Installs the ActionAuth Migrations
    puts "Installing ActionAuth Migrations"
    Rake::Task["action_auth:install:migrations"].invoke

    # Add ActionAuth routes to config/routes.rb
    puts "Installing ActionAuth Routes"
    routes_file_path = Rails.root.join('config', 'routes.rb')
    route_line = "mount ActionAuth::Engine => \"/action_auth\""
    routes_content = File.read(routes_file_path)
    unless routes_content.include?(route_line)
      insert_after = "Rails.application.routes.draw do"
      new_routes_content = routes_content.sub(/(#{insert_after})/i, "\\1\n  #{route_line}\n")
      File.open(routes_file_path, 'w') do |file|
        file.puts new_routes_content
      end
      puts "Added ActionAuth route to config/routes.rb"
    else
      puts "ActionAuth route already present in config/routes.rb"
    end

  end
end
