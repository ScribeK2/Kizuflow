require "test_helper"

class BackwardCompatibilityTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    # Ensure Uncategorized group exists
    @uncategorized = Group.uncategorized
  end

  test "existing workflows should be assigned to Uncategorized group" do
    # Create workflow without explicit group assignment
    workflow = Workflow.create!(title: "Existing Workflow", user: @user)
    
    # Should be assigned to Uncategorized via after_create callback
    assert workflow.groups.any?
    assert_equal "Uncategorized", workflow.groups.first.name
  end

  test "workflows without groups should be accessible to their owners" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    workflow = Workflow.create!(title: "Workflow Without Groups", user: editor, is_public: false)
    
    # Remove all group assignments
    workflow.group_workflows.destroy_all
    
    visible = Workflow.visible_to(editor)
    assert_includes visible.map(&:id), workflow.id
  end

  test "workflows without groups should be accessible to admins" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    workflow = Workflow.create!(title: "Workflow Without Groups", user: @user, is_public: false)
    
    # Remove all group assignments
    workflow.group_workflows.destroy_all
    
    visible = Workflow.visible_to(admin)
    assert_includes visible.map(&:id), workflow.id
  end

  test "public workflows should remain accessible regardless of group assignment" do
    group = Group.create!(name: "Restricted Group")
    public_workflow = Workflow.create!(title: "Public Workflow", user: @user, is_public: true)
    
    # Remove Uncategorized assignment and assign to restricted group
    public_workflow.group_workflows.destroy_all
    GroupWorkflow.create!(group: group, workflow: public_workflow, is_primary: true)
    
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    visible = Workflow.visible_to(user)
    assert_includes visible.map(&:id), public_workflow.id
  end

  test "users without group assignments should see Uncategorized group" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    
    visible_groups = Group.visible_to(user)
    
    assert_includes visible_groups.map(&:id), @uncategorized.id
  end

  test "workflows should default to Uncategorized if no groups selected during creation" do
    workflow = Workflow.create!(
      title: "New Workflow",
      user: @user,
      steps: [{ type: "question", title: "Question", question: "What?" }]
    )
    
    assert workflow.groups.any?
    assert_equal "Uncategorized", workflow.primary_group.name
  end

  test "migration should assign existing workflows to Uncategorized" do
    # Create workflow before migration runs
    workflow = Workflow.create!(title: "Pre-migration Workflow", user: @user)
    
    # Remove group assignment to simulate pre-migration state
    workflow.group_workflows.destroy_all
    
    # Run migration logic
    uncategorized_group = Group.uncategorized
    GroupWorkflow.find_or_create_by!(
      workflow: workflow,
      group: uncategorized_group,
      is_primary: true
    )
    
    workflow.reload
    assert_includes workflow.groups.map(&:id), uncategorized_group.id
  end

  test "fallback: if no groups exist, workflows should still be accessible to owners and admins" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    # Remove all groups except Uncategorized
    Group.where.not(name: "Uncategorized").destroy_all
    
    workflow = Workflow.create!(title: "Workflow", user: editor, is_public: false)
    
    visible = Workflow.visible_to(editor)
    assert_includes visible.map(&:id), workflow.id
  end

  test "workflows in Uncategorized should be visible to users assigned to Uncategorized if public" do
    user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    workflow = Workflow.create!(title: "Uncategorized Workflow", user: @user, is_public: true)
    
    # Ensure it's in Uncategorized
    workflow.group_workflows.destroy_all
    GroupWorkflow.create!(group: @uncategorized, workflow: workflow, is_primary: true)
    
    # Assign user to Uncategorized
    UserGroup.create!(group: @uncategorized, user: user)
    
    visible = Workflow.visible_to(user)
    assert_includes visible.map(&:id), workflow.id
  end

  test "private workflows in groups should be visible to users assigned to that group" do
    # Group membership grants access to all workflows in the group, regardless of is_public
    # is_public is for workflows visible to EVERYONE, not just for group-based access
    user = User.create!(
      email: "user-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    workflow = Workflow.create!(title: "Private Group Workflow", user: @user, is_public: false)
    
    # Ensure it's in Uncategorized
    workflow.group_workflows.destroy_all
    GroupWorkflow.create!(group: @uncategorized, workflow: workflow, is_primary: true)
    
    # Assign user to Uncategorized - this should grant visibility
    UserGroup.create!(group: @uncategorized, user: user)
    
    visible = Workflow.visible_to(user)
    # User assigned to Uncategorized SHOULD see private workflows in that group
    assert_includes visible.map(&:id), workflow.id
  end
  
  test "private workflows in groups should NOT be visible to users NOT assigned to that group" do
    # Users without group assignment should not see private workflows
    user = User.create!(
      email: "user-#{SecureRandom.hex(4)}@test.com",
      password: "password123",
      password_confirmation: "password123"
    )
    restricted_group = Group.create!(name: "Restricted")
    workflow = Workflow.create!(title: "Private Restricted Workflow", user: @user, is_public: false)
    
    # Put workflow in restricted group
    workflow.group_workflows.destroy_all
    GroupWorkflow.create!(group: restricted_group, workflow: workflow, is_primary: true)
    
    # User is NOT assigned to the group
    visible = Workflow.visible_to(user)
    assert_not_includes visible.map(&:id), workflow.id
  end
end

