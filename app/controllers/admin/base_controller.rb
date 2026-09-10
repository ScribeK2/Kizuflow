module Admin
  class BaseController < ApplicationController
    before_action :ensure_admin!

    private

    # Every admin page carries the section sidebar. Overrides
    # ApplicationController#resolve_layout, the same seam PlayerController uses,
    # rather than a class-level `layout` call.
    def resolve_layout
      "admin"
    end
  end
end
