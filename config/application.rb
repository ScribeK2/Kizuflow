# config/application.rb
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# === FIX: Load Devise BEFORE models ===
require "devise"

module Kizuflow
  class Application < Rails::Application
    config.load_defaults 8.0

    # Configuration for the application, engines, and railties goes here.
    config.assets.enabled = true
    config.assets.version = "1.0"
  end
end
