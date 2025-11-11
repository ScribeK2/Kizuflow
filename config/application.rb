# config/application.rb
require_relative "boot"

require "rails/all"

# === CRITICAL: Load Devise BEFORE any models ===
require "devise"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)


module Kizuflow
  class Application < Rails::Application
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties goes here.
    config.assets.enabled = true
    config.assets.version = "1.0"
    
    # esbuild configuration
    # Note: esbuild-rails handles most configuration automatically
    # Custom build options can be added here if needed
  end
end
