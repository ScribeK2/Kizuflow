Rails.application.routes.draw do
  # Temporary debug route - remove after testing
  get '/debug/js_files', to: proc { |env|
    files = Dir.glob(Rails.root.join("app", "javascript", "**", "*.js"))
    [200, {'Content-Type' => 'text/plain'}, [files.join("\n")]]
  }
  
  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }
  root to: "dashboard#index"

  # Mount ActionCable
  mount ActionCable.server => "/cable"

  resources :workflows do
    collection do
      get :import
      post :import_file
    end
    member do
      get :export
      get :export_pdf
      get :preview
      get :variables
      post :save_as_template
      get :start
      post :begin_execution
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
      post :stop
      post :resolve_checkpoint
    end
  end

  # Admin namespace
  namespace :admin do
    root to: 'dashboard#index'
    resources :users, only: [:index, :update] do
      member do
        patch :update_role
      end
    end
    resources :templates, except: [:show]
    resources :workflows, only: [:index, :show]
  end
end
