module Admin
  class BaseController < ApplicationController
    before_action :ensure_admin!
    helper_method :admin_attention

    private

    # Built once per request: the sidebar's count and the Overview read the same
    # object, so they cannot disagree.
    def admin_attention
      @admin_attention ||= Admin::Attention.new
    end

    # Every admin page carries the section sidebar. Overrides
    # ApplicationController#resolve_layout, the same seam PlayerController uses,
    # rather than a class-level `layout` call.
    def resolve_layout
      "admin"
    end
  end
end
