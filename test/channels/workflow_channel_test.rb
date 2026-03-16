require "test_helper"

class WorkflowChannelLogicTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "channel-test-#{SecureRandom.hex(4)}@example.com",
      password: "password123!",
      password_confirmation: "password123!",
      role: "editor"
    )
    @workflow = Workflow.create!(title: "Channel WF", user: @user, graph_mode: true)
    @channel = WorkflowChannel.allocate
    @channel.define_singleton_method(:current_user) { @test_user }
    @channel.instance_variable_set(:@test_user, @user)
  end

  test "detect_version_conflict returns true when versions mismatch" do
    @workflow.update_column(:lock_version, 5)
    result = @channel.send(:detect_version_conflict?, @workflow, 3)
    assert result
  end

  test "detect_version_conflict returns false when client version is 0" do
    @workflow.update_column(:lock_version, 5)
    result = @channel.send(:detect_version_conflict?, @workflow, 0)
    assert_not result
  end

  test "detect_version_conflict returns false when versions match" do
    @workflow.update_column(:lock_version, 5)
    result = @channel.send(:detect_version_conflict?, @workflow, 5)
    assert_not result
  end

  test "apply_ar_step_updates updates step attributes by UUID" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "Original", uuid: "update-uuid")
    updates = [{ "uuid" => "update-uuid", "attributes" => { "title" => "Updated" } }]
    @channel.send(:apply_ar_step_updates, @workflow, updates)
    step.reload
    assert_equal "Updated", step.title
  end

  test "apply_ar_step_updates skips invalid or missing UUIDs" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "Keep", uuid: "keep-uuid")
    updates = [
      { "uuid" => "nonexistent-uuid", "attributes" => { "title" => "Ghost" } },
      { "not_a_uuid" => "bad" }
    ]
    @channel.send(:apply_ar_step_updates, @workflow, updates)
    step.reload
    assert_equal "Keep", step.title
  end

  test "apply_ar_step_updates handles rich text fields" do
    step = Steps::Action.create!(workflow: @workflow, position: 0, title: "RT Step", uuid: "rt-uuid")
    updates = [{ "uuid" => "rt-uuid", "attributes" => { "instructions" => "<p>New instructions</p>" } }]
    @channel.send(:apply_ar_step_updates, @workflow, updates)
    step.reload
    assert_includes step.instructions.to_plain_text, "New instructions"
  end

  test "user_info returns correct structure" do
    info = @channel.send(:user_info)
    assert_equal @user.id, info[:id]
    assert_equal @user.email, info[:email]
    assert info[:name].present?
  end
end
