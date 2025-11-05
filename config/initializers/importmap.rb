# config/initializers/importmap.rb
# Fix importmap path resolution for Render deployment

Rails.application.config.after_initialize do
  # Ensure importmap can find JavaScript files
  # This helps with path resolution in production environments like Render
  if Rails.env.production?
    # Force reload of importmap paths
    Rails.application.config.importmap.cache_sweepers.clear
    Rails.application.config.importmap.cache_sweepers << Rails.root.join("app", "javascript")
    Rails.application.config.importmap.cache_sweepers << Rails.root.join("app", "javascript", "controllers")
    Rails.application.config.importmap.cache_sweepers << Rails.root.join("app", "javascript", "channels")
  end
end
