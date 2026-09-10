require "test_helper"

# A version's RECORD is permanent; only its restorable payload has a limit.
#
# Nothing here is ever deleted. `workflows.published_version_id` is a RESTRICT
# foreign key, and a design that removed rows would have to reason about that on
# every path — so a released version keeps its number, date, publisher, title and
# changelog, and gives up only its steps. metadata_snapshot is ~265 bytes against
# ~9.5KB of steps, so the history costs about 3% of the storage.
class WorkflowVersionRetentionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "vret-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    @workflow = Workflow.create!(title: "Versioned #{SecureRandom.hex(3)}", user: @user,
                                 graph_mode: true)
    @question = Steps::Question.create!(workflow: @workflow, position: 0, title: "Q1",
                                        question: "What?", variable_name: "q1")
    resolve = Steps::Resolve.create!(workflow: @workflow, position: 1, title: "Done",
                                     resolution_type: "success")
    Transition.create!(step: @question, target_step: resolve, position: 0)
    @workflow.update!(start_step: @question)
    file_in_global(@workflow)
  end

  # Each publish must differ, or the dedupe correctly collapses them.
  def publish!(count = 1)
    Array.new(count) do |i|
      @question.update!(question: "What? #{SecureRandom.hex(3)}#{i}")
      WorkflowPublisher.publish(@workflow, @user).version
    end
  end

  def with_limit(limit)
    ENV["WORKFLOW_VERSION_RESTORE_LIMIT"] = limit.to_s
    yield
  ensure
    ENV.delete("WORKFLOW_VERSION_RESTORE_LIMIT")
  end

  # --- the rule ---------------------------------------------------------------

  test "the newest N versions stay restorable" do
    with_limit(3) do
      publish!(5)

      assert_equal 5, @workflow.versions.count, "no version is ever deleted"
      assert_equal 3, @workflow.versions.restorable.count
      assert_equal [5, 4, 3], @workflow.versions.restorable.newest_first.pluck(:version_number)
    end
  end

  test "a released version keeps everything except its steps" do
    with_limit(1) do
      publish!(2)
      old = @workflow.versions.find_by(version_number: 1)

      assert_predicate old, :stripped?
      assert_empty old.steps_snapshot
      assert_not_nil old.stripped_at
      assert_equal 1, old.version_number, "the record is the durable artefact"
      assert_equal @user, old.published_by
      assert_not_nil old.published_at
      assert_predicate old.metadata_snapshot["title"], :present?, "what it was called still answerable"
    end
  end

  test "the published version is never released" do
    with_limit(1) do
      publish!(2)

      assert_predicate @workflow.reload.published_version, :restorable?,
                       "published_version_id is a RESTRICT FK; the newest is always kept"
    end
  end

  test "under the limit nothing is released" do
    with_limit(10) do
      publish!(3)

      assert_equal 3, @workflow.versions.restorable.count
      assert_equal 0, @workflow.versions.stripped.count
    end
  end

  test "releasing is idempotent and does not restamp" do
    with_limit(1) do
      publish!(2)
      old = @workflow.versions.find_by(version_number: 1)
      first_stamp = old.stripped_at

      publish!(1)

      assert_equal first_stamp.to_i, old.reload.stripped_at.to_i
    end
  end

  test "the limit is configurable" do
    assert_equal 10, WorkflowVersion.restore_limit
    with_limit(2) { assert_equal 2, WorkflowVersion.restore_limit }
  end

  # --- what a released version can and cannot do ------------------------------

  test "a released version is excluded from restorable listings" do
    with_limit(2) do
      publish!(4)
      restorable = @workflow.versions.restorable.pluck(:version_number)

      assert_equal [3, 4], restorable.sort
      assert_equal [1, 2], @workflow.versions.stripped.pluck(:version_number).sort
    end
  end

  test "strip_snapshot! on an already released version is a no-op" do
    with_limit(1) do
      publish!(2)
      old = @workflow.versions.find_by(version_number: 1)
      stamp = old.stripped_at

      old.strip_snapshot!

      assert_equal stamp.to_i, old.reload.stripped_at.to_i
    end
  end

  # --- dedupe interaction -----------------------------------------------------

  test "a no-op republish does not push a version past the limit" do
    with_limit(2) do
      publish!(2)
      WorkflowPublisher.publish(@workflow, @user) # identical content

      assert_equal 2, @workflow.versions.count
      assert_equal 2, @workflow.versions.restorable.count,
                   "a republish that wrote nothing must not release anything either"
    end
  end
end
