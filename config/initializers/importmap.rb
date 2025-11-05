# config/initializers/importmap.rb
# Fix importmap path resolution for Render deployment

# Configure importmap BEFORE it tries to resolve paths
Rails.application.config.to_prepare do
  if Rails.env.production?
    # Ensure importmap can find JavaScript files by configuring the resolver
    # Importmap uses Rails.root to resolve paths, so we need to ensure it's correct
    
    # Add app/javascript to the list of paths importmap searches
    javascript_path = Rails.root.join("app", "javascript")
    
    # Ensure the directory exists and is accessible
    if Dir.exist?(javascript_path)
      # Force importmap to recognize this path
      Rails.application.config.importmap.cache_sweepers ||= []
      unless Rails.application.config.importmap.cache_sweepers.include?(javascript_path)
        Rails.application.config.importmap.cache_sweepers << javascript_path
      end
    end
  end
end
