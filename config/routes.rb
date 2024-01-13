ActionAuth::Engine.routes.draw do
  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"
  resources :sessions, only: [:index, :show, :destroy]
  resource  :password, only: [:edit, :update]
  namespace :identity do
    resource :email,              only: [:edit, :update]
    resource :email_verification, only: [:show, :create]
    resource :password_reset,     only: [:new, :edit, :create, :update]
  end

  if ActionAuth.configuration.webauthn_enabled?
    resources :webauthn_credentials, only: [:new, :create, :destroy] do
      post :options, on: :collection, as: 'options_for'
    end

    resource :webauthn_credential_authentications, only: [:new, :create] do
      post :options, on: :collection, as: 'options_for'
    end
  end
end
