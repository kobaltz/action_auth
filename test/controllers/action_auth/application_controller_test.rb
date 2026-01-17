require "test_helper"

module ActionAuth
  class ApplicationControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    class TestableController < ApplicationController
      public :generate_compliant_password
    end

    def setup
      @controller = TestableController.new
    end

    test "generate_compliant_password meets minimum length requirement" do
      password = @controller.generate_compliant_password
      assert password.length >= 12, "Password should be at least 12 characters"
    end

    test "generate_compliant_password contains uppercase letter" do
      password = @controller.generate_compliant_password
      assert password =~ /[A-Z]/, "Password should contain at least one uppercase letter"
    end

    test "generate_compliant_password contains lowercase letter" do
      password = @controller.generate_compliant_password
      assert password =~ /[a-z]/, "Password should contain at least one lowercase letter"
    end

    test "generate_compliant_password contains digit" do
      password = @controller.generate_compliant_password
      assert password =~ /[0-9]/, "Password should contain at least one digit"
    end

    test "generate_compliant_password contains special character" do
      password = @controller.generate_compliant_password
      assert password =~ /[^A-Za-z0-9]/, "Password should contain at least one special character"
    end

    test "generate_compliant_password generates unique passwords" do
      passwords = 10.times.map { @controller.generate_compliant_password }
      assert_equal 10, passwords.uniq.size, "Generated passwords should be unique"
    end

    test "generate_compliant_password passes full complexity validation" do
      password = @controller.generate_compliant_password

      has_uppercase = password =~ /[A-Z]/
      has_lowercase = password =~ /[a-z]/
      has_digit = password =~ /[0-9]/
      has_special = password =~ /[^A-Za-z0-9]/

      assert has_uppercase && has_lowercase && has_digit && has_special,
        "Password '#{password}' should pass all complexity requirements"
    end

    test "generate_compliant_password consistently passes validation over multiple runs" do
      100.times do |i|
        password = @controller.generate_compliant_password

        assert password.length >= 12, "Iteration #{i}: Password should be at least 12 characters"
        assert password =~ /[A-Z]/, "Iteration #{i}: Password should contain uppercase"
        assert password =~ /[a-z]/, "Iteration #{i}: Password should contain lowercase"
        assert password =~ /[0-9]/, "Iteration #{i}: Password should contain digit"
        assert password =~ /[^A-Za-z0-9]/, "Iteration #{i}: Password should contain special char"
      end
    end
  end
end
