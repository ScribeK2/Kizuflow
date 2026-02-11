# Gemfile
source "https://rubygems.org"

ruby "3.3.0"

gem "rails", "~> 8.0.0"
gem "sprockets-rails"
gem "sqlite3", ">= 2.1", group: [:development, :test]
gem "pg", "~> 1.1", group: [:production]
gem "puma", ">= 5.0"
gem "turbo-rails"
gem "stimulus-rails"
gem "importmap-rails"
gem "tailwindcss-rails"
gem "redis", "~> 5.0"
gem "image_processing", "~> 1.2"
gem "bootsnap", ">= 1.4.4", require: false
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Authentication
gem "devise"

# PDF generation
gem "prawn"

# Markdown rendering for step content
gem "redcarpet"

# Rich text editing with Trix
gem "trix-rails"
gem "actiontext"

# Error tracking and performance monitoring (production)
gem "sentry-ruby"
gem "sentry-rails"

group :development, :test do
  gem "debug", platforms: [:mri, :mingw, :x64_mingw]
  gem "rspec-rails"
  gem "capybara"
  gem "selenium-webdriver"
  gem "factory_bot_rails"

  # N+1 query detection - helps catch performance issues during development
  gem "bullet"

  # Code linting and style enforcement
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-performance", require: false
end

group :development do
  gem "web-console"
end
