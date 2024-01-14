Rails.application.routes.draw do
  resources :posts
  mount ActionAuth::Engine => 'action_auth'
  root 'welcome#index'
end
