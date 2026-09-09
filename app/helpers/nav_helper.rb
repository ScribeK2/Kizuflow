module NavHelper
  # Which top-bar destination the current page belongs to.
  #
  # The bar's "you are here" signal is *section*-level, not exact-page: a
  # scenario run launched from the builder still lights Workflows, and every
  # page under /admin lights Admin. Three controllers used to light nothing at
  # all — you could be mid-scenario in the builder with an entirely inert bar.
  #
  # A controller absent from this map deliberately lights nothing. Profiles,
  # registrations, tags, folders and first_runs are reached from inside a
  # section, never from the bar, so highlighting a bar item while you sit on
  # one of them would be a lie.
  NAV_SECTIONS = {
    "dashboard" => :home,
    "workflows" => :workflows,
    "scenarios" => :workflows,
    "steps" => :workflows,
    "workflow_versions" => :workflows,
    # :play is correct but currently unreachable — PlayerController declares
    # `layout "player"`, so /play renders the standalone player shell and the
    # application top bar is not on the page to highlight. Kept because the
    # mapping is the right answer the moment the Player index renders the app
    # shell, and because deleting it would hide the question. The old
    # `controller_name == "player"` condition was dead for the same reason.
    # See test/controllers/nav_controller_test.rb.
    "player" => :play
  }.freeze

  def nav_section
    return :admin if controller_path.start_with?("admin/")
    return :workflows if controller_path.start_with?("workflows/")

    NAV_SECTIONS[controller_path]
  end

  # For `aria: { current: nav_current(:workflows) }` — nil renders no attribute,
  # and the underline in navigation.css keys off [aria-current="page"], so the
  # accessible name and the visible state cannot drift apart.
  def nav_current(section)
    "page" if nav_section == section
  end
end
