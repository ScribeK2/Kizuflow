# Gemfile
source "https://rubygems.org"

ruby "3.3.0"

gem "rails", "~> 8.0.0"
gem "sprockets-rails"
gem "sqlite3", ">= 2.1", group: [:development, :test]
gem "pg", "~> 1.1", group: [:production]
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "tailwindcss-rails"
gem "image_processing", "~> 1.2"
gem "bootsnap", ">= 1.4.4", require: false
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Authentication
gem "devise"

# PDF generation
gem "prawn"

# Sortable.js for drag-and-drop
gem "sortablejs-rails"

# Rich text editing with Trix
gem "trix-rails"
gem "actiontext"

group :development, :test do
  gem "debug", platforms: [:mri, :mingw, :x64_mingw]
  gem "rspec-rails"
  gem "capybara"
  gem "selenium-webdriver"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
end

# ADD THIS LINE – ensures Devise is loaded
gem "devise", require: "devise"

gem "dockerfile-rails", ">= 1.7", :group => :development

gem "redis", "~> 5.4"

gem "aws-sdk-s3", "~> 1.202", :require => false
