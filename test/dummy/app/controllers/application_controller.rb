class ApplicationController < ActionController::Base
  # Simulates an app that requires sign in everywhere and inherits ActionAuth from
  # this controller. See test/support/host_parent_controller_check.rb
  before_action :authenticate_user! if ENV["ACTION_AUTH_HOST_PARENT_CONTROLLER"].present?
end
