require "test_helper"

class WorkflowTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
  end

  test "should create workflow with valid attributes" do
    workflow = Workflow.new(
      title: "Test Workflow",
      description: "A test workflow",
      user: @user,
      steps: [{ type: "question", title: "Question 1", question: "What is your name?" }]
    )
    assert workflow.valid?
    assert workflow.save
  end

  test "should not create workflow without title" do
    workflow = Workflow.new(
      description: "A test workflow",
      user: @user
    )
    assert_not workflow.valid?
    assert_includes workflow.errors[:title], "can't be blank"
  end

  test "should not create workflow without user" do
    workflow = Workflow.new(
      title: "Test Workflow",
      description: "A test workflow"
    )
    assert_not workflow.valid?
    assert_includes workflow.errors[:user_id], "can't be blank"
  end

  test "should belong to user" do
    workflow = Workflow.create!(
      title: "Test Workflow",
      user: @user
    )
    assert_equal @user, workflow.user
  end

  test "should store steps as JSON" do
    steps = [
      { type: "question", title: "Question 1", description: "First question", question: "What is your name?" },
      { type: "decision", title: "Decision 1", condition: "answer == 'yes'" }
    ]
    workflow = Workflow.create!(
      title: "Test Workflow",
      user: @user,
      steps: steps
    )
    
    # JSON stores keys as strings, not symbols
    assert_equal 2, workflow.steps.length
    assert_equal "question", workflow.steps.first["type"]
    assert_equal "Decision 1", workflow.steps.last["title"]
  end

  test "recent scope should order by created_at desc" do
    # Clear existing workflows for this test to avoid fixture interference
    Workflow.where(user: @user).destroy_all
    
    first = Workflow.create!(title: "First", user: @user, created_at: 2.days.ago)
    second = Workflow.create!(title: "Second", user: @user, created_at: 1.day.ago)
    third = Workflow.create!(title: "Third", user: @user, created_at: Time.current)
    
    recent = Workflow.where(user: @user).recent.limit(3)
    assert_equal third.id, recent.first.id
    assert_equal first.id, recent.last.id
  end

  # Permission Tests
  test "can_be_viewed_by? should allow admin to view any workflow" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    private_workflow = Workflow.create!(
      title: "Private Workflow",
      user: @user,
      is_public: false
    )
    
    assert private_workflow.can_be_viewed_by?(admin)
  end

  test "can_be_viewed_by? should allow editor to view own workflows" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    own_workflow = Workflow.create!(
      title: "My Workflow",
      user: editor,
      is_public: false
    )
    
    assert own_workflow.can_be_viewed_by?(editor)
  end

  test "can_be_viewed_by? should allow editor to view public workflows" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    public_workflow = Workflow.create!(
      title: "Public Workflow",
      user: @user,
      is_public: true
    )
    
    assert public_workflow.can_be_viewed_by?(editor)
  end

  test "can_be_viewed_by? should not allow editor to view other user's private workflows" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    other_workflow = Workflow.create!(
      title: "Other User's Workflow",
      user: @user,
      is_public: false
    )
    
    assert_not other_workflow.can_be_viewed_by?(editor)
  end

  test "can_be_viewed_by? should allow user to view public workflows" do
    regular_user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    public_workflow = Workflow.create!(
      title: "Public Workflow",
      user: @user,
      is_public: true
    )
    
    assert public_workflow.can_be_viewed_by?(regular_user)
  end

  test "can_be_viewed_by? should not allow user to view private workflows" do
    regular_user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    private_workflow = Workflow.create!(
      title: "Private Workflow",
      user: @user,
      is_public: false
    )
    
    assert_not private_workflow.can_be_viewed_by?(regular_user)
  end

  test "can_be_edited_by? should allow admin to edit any workflow" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    workflow = Workflow.create!(
      title: "Any Workflow",
      user: @user,
      is_public: false
    )
    
    assert workflow.can_be_edited_by?(admin)
  end

  test "can_be_edited_by? should allow editor to edit own workflows" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    own_workflow = Workflow.create!(
      title: "My Workflow",
      user: editor,
      is_public: false
    )
    
    assert own_workflow.can_be_edited_by?(editor)
  end

  test "can_be_edited_by? should not allow editor to edit other user's workflows" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    other_workflow = Workflow.create!(
      title: "Other User's Workflow",
      user: @user,
      is_public: true
    )
    
    assert_not other_workflow.can_be_edited_by?(editor)
  end

  test "can_be_edited_by? should not allow user to edit workflows" do
    regular_user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    workflow = Workflow.create!(
      title: "Any Workflow",
      user: @user,
      is_public: true
    )
    
    assert_not workflow.can_be_edited_by?(regular_user)
  end

  test "can_be_deleted_by? should follow same rules as edit" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    regular_user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    
    own_workflow = Workflow.create!(title: "My Workflow", user: editor)
    other_workflow = Workflow.create!(title: "Other Workflow", user: @user)
    
    assert other_workflow.can_be_deleted_by?(admin)
    assert own_workflow.can_be_deleted_by?(editor)
    assert_not other_workflow.can_be_deleted_by?(editor)
    assert_not other_workflow.can_be_deleted_by?(regular_user)
  end

  test "visible_to scope should return all workflows for admin" do
    admin = User.create!(
      email: "admin@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "admin"
    )
    workflow1 = Workflow.create!(title: "Private", user: @user, is_public: false)
    workflow2 = Workflow.create!(title: "Public", user: @user, is_public: true)
    
    visible = Workflow.visible_to(admin)
    assert_includes visible.map(&:id), workflow1.id
    assert_includes visible.map(&:id), workflow2.id
  end

  test "visible_to scope should return own + public for editor" do
    editor = User.create!(
      email: "editor@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    own_private = Workflow.create!(title: "My Private", user: editor, is_public: false)
    own_public = Workflow.create!(title: "My Public", user: editor, is_public: true)
    other_private = Workflow.create!(title: "Other Private", user: @user, is_public: false)
    other_public = Workflow.create!(title: "Other Public", user: @user, is_public: true)
    
    visible = Workflow.visible_to(editor)
    assert_includes visible.map(&:id), own_private.id
    assert_includes visible.map(&:id), own_public.id
    assert_includes visible.map(&:id), other_public.id
    assert_not_includes visible.map(&:id), other_private.id
  end

  test "visible_to scope should return only public for user" do
    regular_user = User.create!(
      email: "user@test.com",
      password: "password123",
      password_confirmation: "password123",
      role: "user"
    )
    private_workflow = Workflow.create!(title: "Private", user: @user, is_public: false)
    public_workflow = Workflow.create!(title: "Public", user: @user, is_public: true)
    
    visible = Workflow.visible_to(regular_user)
    assert_not_includes visible.map(&:id), private_workflow.id
    assert_includes visible.map(&:id), public_workflow.id
  end

  test "public_workflows scope should return only public workflows" do
    public1 = Workflow.create!(title: "Public 1", user: @user, is_public: true)
    public2 = Workflow.create!(title: "Public 2", user: @user, is_public: true)
    private_workflow = Workflow.create!(title: "Private", user: @user, is_public: false)
    
    public_workflows = Workflow.public_workflows
    assert_includes public_workflows.map(&:id), public1.id
    assert_includes public_workflows.map(&:id), public2.id
    assert_not_includes public_workflows.map(&:id), private_workflow.id
  end
end

