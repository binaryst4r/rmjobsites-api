Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes
  namespace :api do
    post "auth/login", to: "auth#login"
    post "auth/register", to: "auth#register"
    get "auth/profile", to: "auth#profile"

    # Configuration routes
    get "config/square", to: "config#square"

    # Square catalog routes
    resources :categories, only: [:index, :show] do
      # GET /api/categories/:category_id/products
      get 'products', to: 'products#by_category', on: :member
    end

    resources :products, only: [:index, :show]

    resources :service_requests, only: [:index, :create]
    resources :equipment_rental_requests, only: [:index, :create]

    resources :orders, only: [:create] do
      collection do
        post :calculate
      end
    end
  end

  # Defines the root path route ("/")
  # root "posts#index"
end
