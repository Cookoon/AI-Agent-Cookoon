Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    # Airtable
    get "/chefs", to: "airtable#chefs"
    get "/lieux", to: "airtable#lieux"
    get "/resources", to: "airtable#resources"

    # AI
    post "ai/recommend", to: "ai#recommend"
    post "ai/feedback", to: "ai#feedback"
    post "ai/reset_session", to: "ai#reset_session"

    # Auth ✅
    post   "/login",  to: "sessions#create"
    get    "/me",     to: "sessions#me"
    delete "/logout", to: "sessions#destroy"

      post "ai/ban_list", to: "ai#ban_list"

    # Resources
    resources :feedbacks, only: [:index, :create, :destroy]

    resource :additional_prompt, only: [:show, :update]

    resources :saved_proposals, only: [:index, :create, :destroy] do
      member do
        get :pdf
      end
    end






  end

  root 'pages#home'
  get 'feedback', to: 'pages#feedback'
  get 'historic', to: 'pages#historic'
  get 'prompt', to: 'pages#prompt'
end
