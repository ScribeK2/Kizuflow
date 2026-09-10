# Who may view, edit and delete a workflow. Workflow.visible_to is the viewing
# rule as a query; the two must agree (test/models/workflow_audience_test.rb).
module WorkflowAuthorization
  extend ActiveSupport::Concern

  # - Admins: every workflow.
  # - Editors: their own, and any filed in a group they reach.
  # - Regular users: any filed in a group they reach.
  # A group they reach is one of theirs, a subgroup of one, or Global.
  def can_be_viewed_by?(user)
    return false unless user
    return true if user.admin?
    return true if user.editor? && user == self.user

    workflow_in_groups?(cached_reachable_group_ids(user))
  end

  # - Admins: every workflow.
  # - Editors: their own, and Global workflows another editor owns (spec Q51,
  #   what Public used to allow). A Global workflow an admin owns stays theirs.
  # - Regular users: none.
  def can_be_edited_by?(user)
    return false unless user
    return true if user.admin?
    return false unless user.editor?

    user == self.user || (self.user.editor? && in_global?)
  end

  # - Admins: every workflow.
  # - Editors: only their own.
  # - Regular users: none.
  def can_be_deleted_by?(user)
    return false unless user
    return true if user.admin?

    user.editor? && user == self.user
  end

  private

  # Cached on the user so a list of workflows costs one lookup, not one per row.
  def cached_reachable_group_ids(user)
    user.instance_variable_get(:@_reachable_group_ids) ||
      user.instance_variable_set(:@_reachable_group_ids, Group.reachable_ids_for(user).to_set)
  end

  def workflow_in_groups?(group_ids)
    return false if group_ids.empty?

    if group_workflows.loaded?
      group_workflows.any? { |gw| group_ids.include?(gw.group_id) }
    else
      group_workflows.exists?(group_id: group_ids.to_a)
    end
  end
end
