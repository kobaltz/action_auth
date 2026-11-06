require "test_helper"
require "open3"
require "tmpdir"

# Lockout and suspension are on by default, so they're on for every app that upgrades,
# before and after it runs the new migrations. See test/support/upgrade_check.rb.
class UpgradeTest < ActiveSupport::TestCase
  ROOT = File.expand_path("../..", __dir__)

  def run_check(phase)
    Dir.mktmpdir do |dir|
      env = {
        "ACTION_AUTH_NO_COVERAGE" => "1",
        "DATABASE_URL" => "sqlite3:#{File.join(dir, "upgrade.sqlite3")}",
        "UPGRADE_CHECK" => phase
      }

      Open3.capture2e(env, "bin/rails", "test", "test/support/upgrade_check.rb", chdir: ROOT)
    end
  end

  test "an app that has upgraded but not run the migrations keeps working" do
    output, status = run_check("not_migrated")

    assert status.success?, output
    assert_match(/\b0 failures, 0 errors\b/, output)
    assert_match(/\b15 runs\b/, output)
  end

  test "the migrations apply to that app's data and turn the features on" do
    output, status = run_check("migrated")

    assert status.success?, output
    assert_match(/\b0 failures, 0 errors\b/, output)
    assert_match(/\b4 runs\b/, output)
  end
end
