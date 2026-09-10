module AdminHelper
  # Which sidebar item the current admin page belongs to. Section-level, like
  # NavHelper: folders light Groups because a folder lives inside a group. Add a
  # controller here when you add an admin surface — absence lights nothing.
  ADMIN_SECTIONS = {
    "admin/dashboard" => :overview,
    "admin/users" => :users,
    "admin/groups" => :groups,
    "admin/folders" => :groups,
    "admin/analytics" => :analytics,
    "admin/data_health" => :data_health,
    "admin/smtp_settings" => :email
  }.freeze

  def admin_section
    ADMIN_SECTIONS[controller_path]
  end

  # For `aria: { current: admin_nav_current(:users) }` — nil renders no
  # attribute, and the CSS keys the current state off [aria-current="page"].
  def admin_nav_current(section)
    "page" if admin_section == section
  end

  # A clickable column header for an admin table.
  #
  #   sortable_column_header("Email", :email, current_sort: @sort, frame: "users-table")
  #
  # Clicking an inactive column sorts by +initial+; clicking the active column
  # flips it. Sorting returns to page 1 — an offset taken under the previous
  # ordering means nothing under a new one. Every other filter is carried
  # through, so sorting does not quietly clear a search.
  #
  # +current_sort+ is the ordering actually in effect, with the default already
  # resolved (Admin::UsersFilter#sort_key), so the default column renders as
  # sorted rather than looking untouched while quietly driving the list.
  def sortable_column_header(label, column, current_sort:, frame:, initial: :asc)
    ascending  = "#{column}_asc"
    descending = "#{column}_desc"

    state =
      case current_sort
      when ascending  then :asc
      when descending then :desc
      end

    # Flip when active; otherwise open with this column's natural direction.
    target =
      case state
      when :asc  then descending
      when :desc then ascending
      else            initial.to_sym == :desc ? descending : ascending
      end

    link_to label,
            url_for(filter_params.to_h.merge(sort: target, page: nil)),
            class: ["table__sort", ("is-sorted-#{state}" if state)].compact.join(" "),
            aria: { label: sortable_column_label(label, state) },
            data: { turbo_frame: frame, turbo_action: "advance" }
  end

  # For the th's aria-sort attribute. Screen readers announce a column's state
  # from the header cell, not from the link inside it.
  def sortable_column_aria_sort(column, current_sort:)
    case current_sort
    when "#{column}_asc"  then "ascending"
    when "#{column}_desc" then "descending"
    else                       "none"
    end
  end

  private

  def sortable_column_label(label, state)
    case state
    when :asc  then "#{label}, sorted ascending. Activate to sort descending."
    when :desc then "#{label}, sorted descending. Activate to sort ascending."
    else            "#{label}, not sorted. Activate to sort."
    end
  end
end
