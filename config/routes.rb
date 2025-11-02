Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  root to: "dashboard#index"

  # Mount ActionCable
  mount ActionCable.server => "/cable"

  resources :workflows do
    member do
      get :export
      get :export_pdf
      get :preview
      get :variables
      post :save_as_template
    end
    resources :simulations, only: [:new, :create]
  end

  resources :templates do
    member do
      post :use
    end
  end
  
  resources :simulations, only: [:show] do
    member do
      post :next_step
      get :step
    end
  end
end

