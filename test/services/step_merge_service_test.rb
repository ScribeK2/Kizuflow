require "test_helper"

class StepMergeServiceTest < ActiveSupport::TestCase
  test "returns submitted_steps when no existing steps" do
    service = StepMergeService.new(existing_steps: [], submitted_steps: [{ "id" => "a", "title" => "New" }])
    result = service.call
    assert_equal 1, result.length
    assert_equal "New", result[0]["title"]
  end

  test "returns existing_steps when no submitted steps" do
    service = StepMergeService.new(existing_steps: [{ "id" => "a", "title" => "Old" }], submitted_steps: [])
    result = service.call
    assert_equal 1, result.length
    assert_equal "Old", result[0]["title"]
  end

  test "merges submitted values over existing step data" do
    existing = [{ "id" => "a", "title" => "Old Title", "type" => "question", "variable_name" => "q1" }]
    submitted = [{ "id" => "a", "title" => "New Title", "type" => "question" }]
    result = StepMergeService.new(existing_steps: existing, submitted_steps: submitted).call
    assert_equal "New Title", result[0]["title"]
  end

  test "preserves variable_name for question steps when not in submission" do
    existing = [{ "id" => "a", "type" => "question", "variable_name" => "customer_name" }]
    submitted = [{ "id" => "a", "type" => "question", "title" => "Updated" }]
    result = StepMergeService.new(existing_steps: existing, submitted_steps: submitted).call
    assert_equal "customer_name", result[0]["variable_name"]
  end

  test "preserves variable_name when submitted as blank but existing has value" do
    existing = [{ "id" => "a", "type" => "question", "variable_name" => "customer_name" }]
    submitted = [{ "id" => "a", "type" => "question", "variable_name" => "" }]
    result = StepMergeService.new(existing_steps: existing, submitted_steps: submitted).call
    assert_equal "customer_name", result[0]["variable_name"]
  end

  test "allows explicit variable_name update when submitted with value" do
    existing = [{ "id" => "a", "type" => "question", "variable_name" => "old_name" }]
    submitted = [{ "id" => "a", "type" => "question", "variable_name" => "new_name" }]
    result = StepMergeService.new(existing_steps: existing, submitted_steps: submitted).call
    assert_equal "new_name", result[0]["variable_name"]
  end

  test "handles new steps with no matching existing ID" do
    existing = [{ "id" => "a", "title" => "Existing" }]
    submitted = [{ "id" => "b", "title" => "Brand New" }]
    result = StepMergeService.new(existing_steps: existing, submitted_steps: submitted).call
    assert_equal "Brand New", result[0]["title"]
  end

  test "handles symbol keys via normalize_step" do
    existing = [{ "id" => "a", "title" => "Old", "type" => "question", "variable_name" => "q1" }]
    submitted = [{ id: "a", title: "New", type: "question" }]
    result = StepMergeService.new(existing_steps: existing, submitted_steps: submitted).call
    assert_equal "New", result[0]["title"]
    assert_equal "q1", result[0]["variable_name"]
  end
end
