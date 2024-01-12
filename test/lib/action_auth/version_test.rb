require "test_helper"

module ActionAuth
  class VersionTest < ActiveSupport::TestCase
    test "should be valid" do
      refute_nil ::ActionAuth::VERSION
    end
  end
end
