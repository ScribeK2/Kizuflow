# Sentry Error Tracking Configuration
# Documentation: https://docs.sentry.io/platforms/ruby/guides/rails/
#
# Required environment variable:
#   SENTRY_DSN - Your Sentry DSN (Data Source Name)
#
# Optional environment variables:
#   SENTRY_ENVIRONMENT - Override detected environment (default: Rails.env)
#   SENTRY_RELEASE - Version identifier for releases
#   SENTRY_TRACES_SAMPLE_RATE - Performance monitoring sample rate (0.0-1.0)

if ENV["SENTRY_DSN"].present?
  Sentry.init do |config|
    # DSN is required for Sentry to send events
    config.dsn = ENV["SENTRY_DSN"]
    
    # Environment detection (production, staging, etc.)
    config.environment = ENV.fetch("SENTRY_ENVIRONMENT", Rails.env)
    
    # Release tracking - helps identify which version introduced bugs
    # Set SENTRY_RELEASE in your deployment pipeline or use git SHA
    config.release = ENV.fetch("SENTRY_RELEASE") { 
      `git rev-parse HEAD 2>/dev/null`.strip.presence || "unknown"
    }
    
    # Breadcrumbs help trace the events leading up to an error
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    
    # Performance monitoring (traces)
    # Sample rate: 0.0 = none, 1.0 = all, 0.1 = 10%
    # Start low in production to control costs, increase as needed
    config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", "0.1").to_f
    
    # Profile sample rate (for detailed performance analysis)
    # Only profiles transactions that are sampled for tracing
    config.profiles_sample_rate = ENV.fetch("SENTRY_PROFILES_SAMPLE_RATE", "0.1").to_f
    
    # Send default PII (like user IP) - disabled for privacy
    config.send_default_pii = false
    
    # Exclude common non-actionable exceptions
    config.excluded_exceptions += [
      "ActionController::RoutingError",      # 404s
      "ActionController::InvalidAuthenticityToken",  # CSRF issues (usually bots)
      "ActionController::UnknownFormat",     # Format not supported
      "ActiveRecord::RecordNotFound",        # 404 for resources
      "ActionController::BadRequest",        # Malformed requests
      "Rack::Timeout::RequestTimeoutException"  # Timeouts (handled separately)
    ]
    
    # Filter sensitive parameters from error reports
    config.before_send = lambda do |event, hint|
      # Scrub sensitive data
      if event.request&.data
        event.request.data = filter_sensitive_params(event.request.data)
      end
      
      # Add custom context
      if hint[:exception]
        event.tags[:exception_class] = hint[:exception].class.name
      end
      
      event
    end
    
    # Set user context when available
    config.before_send_transaction = lambda do |event, _hint|
      # Transaction-specific filtering if needed
      event
    end
  end
  
  Rails.logger.info "[Sentry] Initialized with DSN ending in ...#{ENV['SENTRY_DSN'][-10..]}"
else
  Rails.logger.warn "[Sentry] SENTRY_DSN not configured - error tracking disabled"
end

# Helper method to filter sensitive params
def filter_sensitive_params(data)
  return data unless data.is_a?(Hash)
  
  sensitive_keys = %w[password password_confirmation token api_key secret]
  
  data.transform_values do |value|
    if sensitive_keys.any? { |key| value.to_s.downcase.include?(key) }
      "[FILTERED]"
    elsif value.is_a?(Hash)
      filter_sensitive_params(value)
    else
      value
    end
  end
end
