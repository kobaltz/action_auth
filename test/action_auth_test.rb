require 'test_helper'

# Test Engine isolation
class EngineIsolationTest < ActiveSupport::TestCase
  test "engine is isolated" do
    assert ActionAuth::Engine.isolated?
  end
end
