# Configure Active Storage to work with authentication
# Active Storage controllers inherit from ActiveStorage::BaseController
# which doesn't inherit from ApplicationController, so we need to add
# authentication here

Rails.application.config.to_prepare do
  ActiveStorage::BaseController.class_eval do
    # Include Devise helpers if available
    include Devise::Controllers::Helpers if defined?(Devise)
    
    # Add authentication for Active Storage requests
    # This ensures all Active Storage requests require authentication
    before_action :authenticate_user! if respond_to?(:authenticate_user!)
  end
end

