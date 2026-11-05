require "test_helper"

module ActionAuth
  class WebauthnCredentialTest < ActiveSupport::TestCase
    setup do
      @credential = WebauthnCredential.new(
        user: action_auth_users(:one), external_id: "abc", public_key: "key", nickname: "Key", sign_count: 0
      )
    end

    test "is valid with everything set" do
      assert @credential.valid?
    end

    %i[external_id public_key nickname].each do |attribute|
      test "requires #{attribute}" do
        @credential[attribute] = nil
        assert_not @credential.valid?
      end
    end

    test "external ids are unique" do
      @credential.save!

      assert_not @credential.dup.valid?
    end

    test "sign count must be a non-negative 32-bit integer" do
      [-1, 2**32, 1.5].each do |value|
        @credential.sign_count = value
        assert_not @credential.valid?, "#{value} should be invalid"
      end

      @credential.sign_count = 2**32 - 1
      assert @credential.valid?
    end

    test "belongs to its user" do
      assert_equal action_auth_users(:one), @credential.user
    end

    test "defaults to an unknown key type" do
      assert @credential.unknown?
    end
  end
end
