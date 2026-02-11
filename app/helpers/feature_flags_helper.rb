# frozen_string_literal: true

# View helpers for feature flag checks
module FeatureFlagsHelper
  # Check if graph mode is the default for new workflows
  delegate :graph_mode_default?, to: :FeatureFlags

  # Determine whether to show the Graph Mode toggle in the UI
  # Hidden when graph mode is the default (cleaner UX)
  # Can be forced visible with ?show_mode_toggle=1 for admin/debug purposes
  def show_graph_mode_toggle?
    return true unless graph_mode_default?

    params[:show_mode_toggle].present?
  end
end
