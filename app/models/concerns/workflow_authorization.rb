# frozen_string_literal: true

# Handles authorization logic for workflows.
# Determines who can view, edit, and delete workflows based on user roles and group membership.
module WorkflowAuthorization
  extend ActiveSupport::Concern

  # Check if a user can view this workflow
  #
  # Access rules:
  # - Admins: can view all workflows
  # - Editors: can view own workflows, public workflows, or workflows in assigned groups
  # - Users: can view public workflows, workflows in assigned groups, or workflows without groups
  #
  # @param user [User] The user to check access for
  # @return [Boolean] True if user can view this workflow
  def can_be_viewed_by?(user)
    return false unless user

    # Admins can view all workflows
    return true if user.admin?

    # Editors can view their own workflows + public workflows + workflows in assigned groups
    if user.editor?
      return true if user == self.user
      return true if is_public?
      # Check if workflow is in user's assigned groups (optimized single query)
      if user.groups.any?
        accessible_group_ids = Group.accessible_group_ids_for(user)
        return true if groups.where(id: accessible_group_ids).any?
      end
      return true if groups.empty? # Workflows without groups (backward compatibility)
      return false
    end

    # Users: can view public workflows + workflows in assigned groups + workflows without groups
    return true if is_public?

    # Check if workflow is in user's assigned groups (optimized single query)
    if user.groups.any?
      accessible_group_ids = Group.accessible_group_ids_for(user)
      return true if groups.where(id: accessible_group_ids).any?
    end

    # Workflows without groups are accessible to all users (backward compatibility)
    return true if groups.empty?

    false
  end

  # Check if a user can edit this workflow
  #
  # Access rules:
  # - Admins: can edit all workflows
  # - Editors: can edit own workflows or public workflows created by other editors
  # - Users: cannot edit workflows
  #
  # @param user [User] The user to check access for
  # @return [Boolean] True if user can edit this workflow
  def can_be_edited_by?(user)
    return false unless user

    # Admins can edit all workflows
    return true if user.admin?

    # Editors can edit their own workflows or public workflows created by other editors
    if user.editor?
      return true if user == self.user
      return true if is_public? && self.user.editor?
    end

    false
  end

  # Check if a user can delete this workflow
  #
  # Access rules:
  # - Admins: can delete all workflows
  # - Editors: can only delete their own workflows
  # - Users: cannot delete workflows
  #
  # @param user [User] The user to check access for
  # @return [Boolean] True if user can delete this workflow
  def can_be_deleted_by?(user)
    return false unless user

    # Admins can delete all workflows
    return true if user.admin?

    # Editors can only delete their own workflows
    user.editor? && user == self.user
  end
end
