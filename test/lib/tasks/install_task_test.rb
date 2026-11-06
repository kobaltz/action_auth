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

  test "the generated initializer documents lockout, suspension and OAuth, without turning anything on" do
    run_install
    initializer = @root.join("config/initializers/action_auth.rb").read

    %w[account_lockout_enabled account_lockout_max_attempts account_lockout_duration
      account_suspension_enabled oauth_provider].each do |setting|
      assert_includes initializer, "#   config.#{setting}"
    end

    assert initializer.lines.all? { |line| line.start_with?("#") || line.strip.empty? }
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

  {
    "the README's manual install" => "mount ActionAuth::Engine => 'action_auth'",
    "another path" => %(mount ActionAuth::Engine => "/auth"),
    "the at: option" => %(mount ActionAuth::Engine, at: "/auth"),
    "parentheses" => %[mount(ActionAuth::Engine => "/auth")],
    "a block on one line" => %[constraints(subdomain: "app") { mount ActionAuth::Engine => "/auth" }]
  }.each do |description, mount|
    test "leaves a mount written with #{description} alone" do
      routes = "Rails.application.routes.draw do\n  #{mount}\nend\n"
      @root.join("config/routes.rb").write(routes)

      run_install

      assert_equal routes, @root.join("config/routes.rb").read
    end
  end

  test "a commented out mount doesn't count as mounted" do
    @root.join("config/routes.rb").write(<<~RUBY)
      Rails.application.routes.draw do
        # mount ActionAuth::Engine => "/old"
      end
    RUBY

    run_install

    assert_includes @root.join("config/routes.rb").read, %(  mount ActionAuth::Engine => "/action_auth"\n)
  end
end
