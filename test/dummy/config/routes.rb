Rails.application.routes.draw do
  mount ActionAuth::Engine => 'action_auth'
  root 'welcome#index'
end
