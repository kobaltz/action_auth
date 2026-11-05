require "test_helper"
require "rails/generators/test_case"
require "generators/action_auth/views/views_generator"

class ActionAuth::Generators::ViewsGeneratorTest < Rails::Generators::TestCase
  tests ActionAuth::Generators::ViewsGenerator
  destination File.expand_path("../../tmp/generator_test", __dir__)
  setup :prepare_destination

  ENGINE_VIEWS = File.expand_path("../../app/views/action_auth", __dir__)

  test "copies every view by default" do
    run_generator

    Dir[File.join(ENGINE_VIEWS, "**/*.erb")].each do |source|
      relative = source.delete_prefix("#{ENGINE_VIEWS}/")
      assert_file "app/views/action_auth/#{relative}", File.read(source)
    end
  end

  test "every folder of views can be selected" do
    folders = Dir.children(ENGINE_VIEWS).select { |name| File.directory?(File.join(ENGINE_VIEWS, name)) }

    assert_equal folders.sort, ActionAuth::Generators::ViewsGenerator::SCOPES.sort
  end

  test "copies only the scopes asked for" do
    run_generator %w[sessions registrations]

    assert_file "app/views/action_auth/sessions/new.html.erb"
    assert_file "app/views/action_auth/sessions/_account.html.erb"
    assert_file "app/views/action_auth/registrations/new.html.erb"
    assert_no_file "app/views/action_auth/passwords/edit.html.erb"
    assert_no_file "app/views/action_auth/shared/_flash.html.erb"
  end

  test "leaves the layout alone unless asked" do
    run_generator %w[sessions]

    assert_no_file "app/views/layouts/action_auth/application.html.erb"
  end

  test "copies the layout when asked" do
    run_generator %w[sessions --layout]

    assert_file "app/views/layouts/action_auth/application.html.erb", /stylesheet_link_tag "action_auth\/application"/
  end

  test "an unknown scope stops with a helpful message and copies nothing" do
    output = capture(:stderr) { run_generator %w[sesions] }

    assert_match "Unknown scope: sesions", output
    assert_no_file "app/views/action_auth/sessions/new.html.erb"
  end
end
