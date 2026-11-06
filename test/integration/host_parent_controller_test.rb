require "test_helper"
require "open3"

class HostParentControllerTest < ActiveSupport::TestCase
  test "ActionAuth works when it inherits from an app's sign-in-required ApplicationController" do
    root = File.expand_path("../..", __dir__)
    env = { "ACTION_AUTH_HOST_PARENT_CONTROLLER" => "1", "ACTION_AUTH_NO_COVERAGE" => "1" }

    output, status = Open3.capture2e(env, "bin/rails", "test", "test/support/host_parent_controller_check.rb", chdir: root)

    assert status.success?, output
    assert_match(/\b6 runs\b/, output)
  end
end
