ActionAuth::Engine.routes.draw do
  get  "sign_in", to: "sessions#new"
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "registrations#new"
  post "sign_up", to: "registrations#create"

  namespace :identity do
    resource :email,              only: [:edit, :update]
    resource :email_verification, only: [:show, :create, :update]
    resource :password_reset,     only: [:new, :edit, :create, :update]
  end
  resource  :password, only: [:edit, :update]
  namespace :sessions do
    if ActionAuth.configuration.webauthn_enabled? && ActionAuth.configuration.passkey_only?
      resources :passkeys, only: [:new, :create]
    end
  end
  resources :sessions, only: [:index, :destroy]

  if ActionAuth.configuration.allow_user_deletion?
    resource  :users, only: [:destroy]
  end

  if ActionAuth.configuration.webauthn_enabled?
    resources :webauthn_credentials, only: [:new, :create, :destroy] do
      post :options, on: :collection, as: 'options_for'
    end

    resource :webauthn_credential_authentications, only: [:new, :create]
  end

  if ActionAuth.configuration.magic_link_enabled?
    namespace :magics do
      resource :sign_ins, only: [:show, :create]
      resource :requests, only: [:new, :create]
    end
  end

  if ActionAuth.configuration.sms_auth_enabled?
    namespace :sms_auths do
      resource :sign_ins, only: [:show, :create]
      resource :requests, only: [:new, :create]
    end
  end

  if ActionAuth.configuration.oauth_enabled?
    # OmniAuth answers POST auth/:provider for every configured provider before
    # the router sees it. This route names the path, and catches any other provider.
    post  "auth/:provider",          to: "provider_callbacks#failure", as: :oauth_request
    get   "auth/failure",            to: "provider_callbacks#failure", as: :oauth_failure
    match "auth/:provider/callback", to: "provider_callbacks#create",  as: :oauth_callback, via: [:get, :post]

    resources :connected_accounts, only: [:destroy]
  end
end
