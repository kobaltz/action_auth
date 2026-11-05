require "test_helper"
require "rake"
require "tmpdir"

class InstallTaskTest < ActiveSupport::TestCase
  ROUTES = <<~RUBY
    Rails.application.routes.draw do
      root "welcome#index"
    end
  RUBY

  setup do
    @root = Pathname.new(Dir.mktmpdir)
    @root.join("config/initializers").mkpath
    @root.join("config/routes.rb").write(ROUTES)

    @rake = Rake::Application.new
    @rake.init("rake", [])
    Rake.application = @rake
    load File.expand_path("../../../lib/tasks/action_auth_tasks.rake", __dir__)
    @migrations_copied = 0
    Rake::Task.define_task("action_auth:install:migrations") { @migrations_copied += 1 }
  end

  teardown { FileUtils.remove_entry(@root) }

  def run_install
    original_root = Rails.method(:root)
    root = @root
    Rails.define_singleton_method(:root) { root }

    capture_io do
      Rake::Task["action_auth:install"].reenable
      Rake::Task["action_auth:install:migrations"].reenable
      Rake::Task["action_auth:install"].invoke
    end
  ensure
    Rails.define_singleton_method(:root, original_root)
  end

  test "creates the initializer, mounts the engine and copies migrations" do
    run_install

    assert_includes @root.join("config/routes.rb").read, %(mount ActionAuth::Engine => "/action_auth")
    assert_equal 1, @migrations_copied
    assert @root.join("config/initializers/action_auth.rb").exist?
  end

  test "the generated initializer documents the customization settings" do
    run_install

    initializer = @root.join("config/initializers/action_auth.rb").read
    %w[layout parent_controller after_sign_in_path after_sign_out_path].each do |setting|
      assert_includes initializer, "config.#{setting}"
    end
  end

  test "running it again changes nothing" do
    run_install
    routes = @root.join("config/routes.rb").read
    @root.join("config/initializers/action_auth.rb").write("# mine")

    run_install

    assert_equal routes, @root.join("config/routes.rb").read
    assert_equal "# mine", @root.join("config/initializers/action_auth.rb").read
  end
end
