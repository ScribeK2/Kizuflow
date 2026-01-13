require "test_helper"

class WorkflowConcurrencyTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: "editor"
    )
    @workflow = Workflow.create!(
      title: "Concurrent Test",
      user: @user,
      steps: [{ "type" => "question", "title" => "Step 1", "question" => "Initial?" }]
    )
  end

  test "lock_version increments on save" do
    initial_version = @workflow.lock_version
    assert_equal 0, initial_version

    @workflow.update!(title: "Updated Title")
    assert_equal 1, @workflow.lock_version

    @workflow.update!(title: "Updated Again")
    assert_equal 2, @workflow.lock_version
  end

  test "optimistic locking raises StaleObjectError on version mismatch" do
    # Load two instances of the same workflow
    workflow1 = Workflow.find(@workflow.id)
    workflow2 = Workflow.find(@workflow.id)

    # Both have the same initial version
    assert_equal workflow1.lock_version, workflow2.lock_version

    # First update succeeds
    workflow1.update!(title: "Update from instance 1")
    
    # Second update should fail because lock_version changed
    workflow2.title = "Update from instance 2"
    
    assert_raises(ActiveRecord::StaleObjectError) do
      workflow2.save!
    end
  end

  test "concurrent step modifications are protected" do
    workflow1 = Workflow.find(@workflow.id)
    workflow2 = Workflow.find(@workflow.id)

    # First user adds a step
    steps1 = workflow1.steps.dup
    steps1 << { "type" => "action", "title" => "Step from user 1", "instructions" => "Do thing 1" }
    workflow1.update!(steps: steps1)

    # Second user tries to add a step (based on stale data)
    steps2 = workflow2.steps.dup  # This is the OLD steps array
    steps2 << { "type" => "action", "title" => "Step from user 2", "instructions" => "Do thing 2" }
    workflow2.steps = steps2

    # This should raise an error because lock_version mismatches
    assert_raises(ActiveRecord::StaleObjectError) do
      workflow2.save!
    end

    # Reload to verify only the first update succeeded
    @workflow.reload
    assert_equal 2, @workflow.steps.length  # 1 original + 1 from user 1
    assert_equal "Step from user 1", @workflow.steps.last["title"]
  end

  test "reload resets lock_version for retry" do
    workflow1 = Workflow.find(@workflow.id)
    workflow2 = Workflow.find(@workflow.id)

    # First user updates
    workflow1.update!(title: "First update")

    # Second user's save fails
    workflow2.title = "Second update"
    assert_raises(ActiveRecord::StaleObjectError) do
      workflow2.save!
    end

    # After reload, second user can save
    workflow2.reload
    assert_equal workflow1.lock_version, workflow2.lock_version
    
    workflow2.title = "Second update after reload"
    assert workflow2.save
    assert_equal "Second update after reload", workflow2.title
  end

  test "save without validation still increments lock_version" do
    initial_version = @workflow.lock_version
    
    # This simulates what autosave does
    @workflow.title = "Autosaved title"
    @workflow.save(validate: false)
    
    assert_equal initial_version + 1, @workflow.lock_version
  end

  test "multiple rapid updates increment lock_version correctly" do
    10.times do |i|
      @workflow.update!(title: "Update #{i}")
    end
    
    assert_equal 10, @workflow.lock_version
  end

  test "transaction with lock prevents concurrent modifications" do
    # This tests the pattern used in WorkflowChannel#autosave
    workflow1 = Workflow.find(@workflow.id)
    
    # Simulate first user locking and updating
    Workflow.transaction do
      workflow1.lock!
      workflow1.title = "Locked update"
      workflow1.save!
    end

    # Verify the update succeeded
    @workflow.reload
    assert_equal "Locked update", @workflow.title
    assert_equal 1, @workflow.lock_version
  end
end
