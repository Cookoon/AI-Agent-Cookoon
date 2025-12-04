Rails.application.routes.draw do
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    get "/chefs", to: "airtable#chefs"
    get "/lieux", to: "airtable#lieux"
    get "/resources", to: "airtable#resources"

    # AI endpoints
    post "ai/recommend", to: "ai#recommend"
    post "ai/feedback", to: "ai#feedback"
    post "ai/reset_session", to: "ai#reset_session"

    # Other resources
    resources :feedbacks, only: [:index, :destroy], controller: "ai_feedbacks"
    resources :saved_proposals, only: [:index, :create, :destroy]
  end

  root 'pages#home'

  get 'feedback', to: 'pages#feedback'
  get 'historic', to: 'pages#historic'
end
