# config/initializers/importmap.rb
# Ensure importmap can find JavaScript files in production
Rails.application.config.after_initialize do
  # Add app/javascript to cache sweepers if not already present
  unless Rails.application.config.importmap.cache_sweepers.include?(Rails.root.join("app", "javascript"))
    Rails.application.config.importmap.cache_sweepers << Rails.root.join("app", "javascript")
  end
end
