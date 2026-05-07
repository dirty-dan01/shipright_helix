Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :orders, only: [ :index, :show ] do
    member do
      post :transition
      post :sync_tracking
    end
    collection do
      post :bulk_update
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "orders#index"
end
