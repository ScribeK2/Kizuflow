# config/application.rb
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Kizuflow
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # -----------------------------------------------------------------
    # RAILS 8 FIX: Force DATABASE_URL in production (Render only)
    # -----------------------------------------------------------------
    # `config.database_configuration` is read-only in Rails 8.
    # Use `config.active_record.database_configuration` instead.
    if Rails.env.production?
      config.active_record.database_configuration = {
        "production" => { "url" => ENV["DATABASE_URL"] }
      }
    end

    # -----------------------------------------------------------------
    # 2. Settings in config/environments/* take precedence over these.
    # -----------------------------------------------------------------
    # (Leave all the defaults you already have – they apply to dev/test.)

    # Configuration for the application, engines, and railties goes here.
    #
    # Examples:
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rails time:zones" for a list.
    # config.time_zone = "UTC"

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join("my", "locales", "*.{rb,yml}").to_s]
    # config.i18n.default_locale = :de

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets.
    config.assets.version = "1.0"

    # -----------------------------------------------------------------
    # 3. DO NOT TOUCH ANYTHING BELOW THIS LINE
    # -----------------------------------------------------------------
    # (All the default Rails 8 config you already have stays exactly the same.)
  end
end
