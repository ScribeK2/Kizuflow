require "test_helper"

# The versions page under the "record is permanent, payload is not" rule.
#
# A released version keeps its number, date, publisher and changelog and gives up
# only its steps — so the page has to be honest about which of those it can still
# act on. The trap it is guarding against is a control that is present and fails.
class VersionHistoryPageTest < ActionDispatch::IntegrationTest
  setup do
    @editor = User.create!(
      email: "vhist-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    @workflow = Workflow.create!(title: "History #{SecureRandom.hex(3)}", user: @editor,
                                 graph_mode: true)
    @question = Steps::Question.create!(workflow: @workflow, position: 0, title: "Q1",
                                        question: "What?", variable_name: "q1")
    resolve = Steps::Resolve.create!(workflow: @workflow, position: 1, title: "Done",
                                     resolution_type: "success")
    Transition.create!(step: @question, target_step: resolve, position: 0)
    @workflow.update!(start_step: @question)
    # An audience that is not Global: another editor may edit a Global workflow
    # (spec Q51), and the changelog-permission test below needs an outsider.
    GroupWorkflow.create!(group: Group.create!(name: "History Group #{SecureRandom.hex(3)}"),
                          workflow: @workflow, is_primary: true)
    sign_in @editor
  end

  def publish!(count = 1)
    Array.new(count) do |i|
      @question.update!(question: "What? #{SecureRandom.hex(3)}#{i}")
      WorkflowPublisher.publish(@workflow.reload, @editor).version
    end
  end

  def with_limit(limit)
    ENV["WORKFLOW_VERSION_RESTORE_LIMIT"] = limit.to_s
    yield
  ensure
    ENV.delete("WORKFLOW_VERSION_RESTORE_LIMIT")
  end

  # --- what a released version looks like -------------------------------------

  test "a released version says so instead of offering a Restore that would fail" do
    with_limit(1) do
      publish!(3)

      get workflow_versions_path(@workflow)

      assert_response :success
      assert_match(/Snapshot no longer kept/, response.body)
      # v1 and v2 are released; only the current v3 remains, and the current
      # version is never offered for restore anyway.
      assert_select "form[action=?]", workflow_restore_version_path(@workflow, @workflow.versions.find_by(version_number: 1)), false
    end
  end

  test "a restorable, non-current version still offers Restore" do
    with_limit(10) do
      versions = publish!(2)

      get workflow_versions_path(@workflow)

      assert_response :success
      assert_select "form[action=?]", workflow_restore_version_path(@workflow, versions.first)
    end
  end

  test "released versions are not offered in the compare dropdowns" do
    with_limit(2) do
      publish!(4)

      get workflow_versions_path(@workflow)

      assert_response :success
      released = @workflow.versions.stripped.pluck(:id)
      restorable = @workflow.versions.restorable.pluck(:id)
      assert_equal 2, released.size, "two of the four should have been released"

      offered = css_select("select#v1 option").map { |o| o["value"].to_i }
      assert_equal restorable.sort, offered.sort,
                   "the compare control must offer exactly what it can diff"
      released.each do |id|
        assert_not_includes offered, id, "a released version has no snapshot to diff"
      end
    end
  end

  test "the page states the rule rather than leaving it to be discovered" do
    with_limit(4) do
      publish!(1)

      get workflow_versions_path(@workflow)

      assert_response :success
      assert_match(/newest\s+4\s+stay restorable/m, response.body)
    end
  end

  # --- the retroactive changelog ----------------------------------------------

  test "an editor can write a changelog after the fact" do
    version = publish!(1).first
    assert_nil version.changelog

    patch workflow_update_version_path(@workflow, version),
          params: { workflow_version: { changelog: "Reworded the opening question" } }

    assert_redirected_to workflow_versions_path(@workflow, page: nil)
    assert_equal "Reworded the opening question", version.reload.changelog
  end

  test "a released version can still be annotated" do
    with_limit(1) do
      publish!(2)
      released = @workflow.versions.find_by(version_number: 1)
      assert_predicate released, :stripped?

      patch workflow_update_version_path(@workflow, released),
            params: { workflow_version: { changelog: "The one before the rewrite" } }

      assert_equal "The one before the rewrite", released.reload.changelog,
                   "the record is the durable artefact — improving it is the point"
    end
  end

  test "someone who cannot edit the workflow cannot write a changelog" do
    version = publish!(1).first
    outsider = User.create!(
      email: "outsider-#{SecureRandom.hex(4)}@example.com",
      password: "password123!", password_confirmation: "password123!", role: "editor"
    )
    sign_in outsider

    patch workflow_update_version_path(@workflow, version),
          params: { workflow_version: { changelog: "not mine to write" } }

    assert_nil version.reload.changelog
  end

  # --- pagination -------------------------------------------------------------

  test "the list paginates, because the record grows forever" do
    with_limit(2) do
      publish!(Workflows::VersionsController::PER_PAGE + 2)

      get workflow_versions_path(@workflow)
      assert_response :success
      assert_select ".pagination__item"
      assert_match(/Page 1 of 2/, response.body)

      get workflow_versions_path(@workflow, page: 2)
      assert_response :success
      assert_match(/Page 2 of 2/, response.body)
    end
  end

  test "an out-of-range page clamps rather than rendering an empty table" do
    publish!(1)

    get workflow_versions_path(@workflow, page: 99)

    assert_response :success
    assert_match(/v1/, response.body)
  end
end
