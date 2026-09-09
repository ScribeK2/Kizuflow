module Workflows
  class VersionsController < BaseController
    before_action :ensure_can_manage_workflows!
    before_action :ensure_can_view_workflow!

    PER_PAGE = 25

    # GET /workflows/:workflow_id/versions
    #
    # Paginated because a version's record is permanent: only its restorable
    # snapshot is released, so this list only ever grows. It is the one page
    # guaranteed to get long.
    def index
      scope = @workflow.versions.newest_first.includes(:published_by)
      @total_versions = scope.count
      @total_pages = [(@total_versions / PER_PAGE.to_f).ceil, 1].max
      @page = params[:page].to_i.clamp(1, @total_pages)
      @versions = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
      # The compare control offers only what it can actually diff, and that has to
      # be every restorable version rather than this page's — otherwise which
      # versions you can compare depends on which page you are looking at.
      @comparable = @workflow.versions.restorable.newest_first
      render "workflows/versions"
    end
  end
end
