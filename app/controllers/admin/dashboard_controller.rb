class Admin::DashboardController < Admin::BaseController
  # Overview: only what is waiting on an administrator (admin_attention). The
  # counts and recent-item lists were dropped on purpose — the Users table sorted
  # by Joined already answers "who signed up", and a total is nothing to act on.
  def index; end
end
