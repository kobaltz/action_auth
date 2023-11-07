Rails.application.routes.draw do
  mount ActionAuth::Engine => "/action_auth"
end
