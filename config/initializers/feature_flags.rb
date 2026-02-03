# frozen_string_literal: true

# Simple feature flags for gradual rollout
# Override via environment variables
#
# Usage:
#   FeatureFlags.graph_mode_default?  # => true (default)
#   GRAPH_MODE_DEFAULT=false rails s  # => revert to linear mode as default
#
module FeatureFlags
  class << self
    # Graph Mode is now the default for new workflows
    # Set GRAPH_MODE_DEFAULT=false to revert to linear mode as default
    def graph_mode_default?
      ENV.fetch('GRAPH_MODE_DEFAULT', 'true').downcase == 'true'
    end

    # Allow URL param override for demo/testing
    # Usage: ?force_linear_mode=1 when creating new workflow
    # Set ALLOW_LINEAR_MODE_OVERRIDE=false to disable this escape hatch
    def allow_linear_mode_override?
      ENV.fetch('ALLOW_LINEAR_MODE_OVERRIDE', 'true').downcase == 'true'
    end
  end
end
