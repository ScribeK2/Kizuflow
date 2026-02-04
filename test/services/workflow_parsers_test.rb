require "test_helper"

class WorkflowParsersTest < ActiveSupport::TestCase
  # ============================================================================
  # BaseParser Tests
  # ============================================================================

  test "base parser detects graph format by transitions" do
    parser = WorkflowParsers::JsonParser.new('{}')
    steps = [
      { 'type' => 'question', 'title' => 'Q1', 'transitions' => [{ 'target_uuid' => 'step-2' }] },
      { 'type' => 'resolve', 'title' => 'End' }
    ]

    assert parser.send(:detect_graph_format, steps)
  end

  test "base parser detects linear format without transitions" do
    parser = WorkflowParsers::JsonParser.new('{}')
    steps = [
      { 'type' => 'question', 'title' => 'Q1' },
      { 'type' => 'action', 'title' => 'A1' }
    ]

    assert_not parser.send(:detect_graph_format, steps)
  end

  test "base parser ensures step UUIDs" do
    parser = WorkflowParsers::JsonParser.new('{}')
    steps = [
      { 'type' => 'question', 'title' => 'Q1' },
      { 'type' => 'action', 'title' => 'A1', 'id' => 'existing-id' }
    ]

    parser.send(:ensure_step_uuids, steps)

    assert steps[0]['id'].present?, "First step should have UUID assigned"
    assert_equal 'existing-id', steps[1]['id'], "Existing ID should be preserved"
  end

  test "base parser converts linear to graph format" do
    parser = WorkflowParsers::JsonParser.new('{}')
    parser.send(:ensure_step_uuids, steps = [
      { 'type' => 'question', 'title' => 'Q1' },
      { 'type' => 'action', 'title' => 'A1' }
    ])

    converted = parser.send(:convert_to_graph_format, steps)

    # First step should have transition to second
    assert converted[0]['transitions'].present?
    assert_equal converted[1]['id'], converted[0]['transitions'][0]['target_uuid']
  end

  test "base parser converts decision branches to transitions" do
    parser = WorkflowParsers::JsonParser.new('{}')
    steps = [
      { 'id' => 'step-1', 'type' => 'question', 'title' => 'Q1' },
      {
        'id' => 'step-2',
        'type' => 'decision',
        'title' => 'Check',
        'branches' => [
          { 'condition' => "answer == 'yes'", 'path' => 'Success' }
        ],
        'else_path' => 'Failure'
      },
      { 'id' => 'step-3', 'type' => 'action', 'title' => 'Success', 'instructions' => 'Done!' },
      { 'id' => 'step-4', 'type' => 'action', 'title' => 'Failure', 'instructions' => 'Failed' }
    ]

    converted = parser.send(:convert_to_graph_format, steps)
    decision_step = converted[1]

    assert decision_step['transitions'].present?
    assert decision_step['transitions'].any? { |t| t['target_uuid'] == 'step-3' },
           "Should have transition to Success step"
  end

  test "base parser handles resolve steps as terminal" do
    parser = WorkflowParsers::JsonParser.new('{}')
    steps = [
      { 'id' => 'step-1', 'type' => 'question', 'title' => 'Q1' },
      { 'id' => 'step-2', 'type' => 'resolve', 'title' => 'End', 'resolution_type' => 'success' }
    ]

    converted = parser.send(:convert_to_graph_format, steps)
    resolve_step = converted.find { |s| s['type'] == 'resolve' }

    assert_equal [], resolve_step['transitions'], "Resolve step should have no transitions"
  end

  # ============================================================================
  # JSON Parser Tests
  # ============================================================================

  test "json parser parses valid graph mode JSON" do
    content = {
      title: "Test Workflow",
      description: "A test",
      graph_mode: true,
      start_node_uuid: "step-1",
      steps: [
        {
          id: "step-1",
          type: "question",
          title: "Q1",
          question: "Name?",
          transitions: [{ target_uuid: "step-2" }]
        },
        {
          id: "step-2",
          type: "resolve",
          title: "End"
        }
      ]
    }.to_json

    parser = WorkflowParsers::JsonParser.new(content)
    result = parser.parse

    assert result.present?
    assert_equal "Test Workflow", result[:title]
    assert result[:graph_mode]
    assert_equal "step-1", result[:start_node_uuid]
    assert_equal 2, result[:steps].length
  end

  test "json parser handles wrapped workflow format" do
    content = {
      workflow: {
        title: "Wrapped Workflow",
        steps: [{ type: "action", title: "Step 1" }]
      }
    }.to_json

    parser = WorkflowParsers::JsonParser.new(content)
    result = parser.parse

    assert result.present?
    assert_equal "Wrapped Workflow", result[:title]
  end

  test "json parser rejects invalid JSON" do
    parser = WorkflowParsers::JsonParser.new("{ invalid json")
    result = parser.parse

    assert_nil result
    assert parser.errors.any? { |e| e.include?("Invalid JSON") }
  end

  test "json parser rejects missing title" do
    content = { steps: [{ type: "action", title: "Step 1" }] }.to_json

    parser = WorkflowParsers::JsonParser.new(content)
    result = parser.parse

    assert_nil result, "Parser should return nil when title is missing"
    assert parser.errors.any? { |e| e.downcase.include?("title") },
           "Parser should have an error about missing title"
  end

  # ============================================================================
  # YAML Parser Tests
  # ============================================================================

  test "yaml parser parses valid YAML" do
    content = <<~YAML
      title: "YAML Workflow"
      description: "Test"
      graph_mode: true
      steps:
        - id: "step-1"
          type: question
          title: "Q1"
          question: "What?"
          transitions:
            - target_uuid: "step-2"
        - id: "step-2"
          type: resolve
          title: "End"
    YAML

    parser = WorkflowParsers::YamlParser.new(content)
    result = parser.parse

    assert result.present?
    assert_equal "YAML Workflow", result[:title]
    assert result[:graph_mode]
  end

  test "yaml parser handles symbol keys" do
    content = <<~YAML
      title: "Symbol Keys Workflow"
      steps:
        - type: action
          title: "Step 1"
          instructions: "Do it"
    YAML

    parser = WorkflowParsers::YamlParser.new(content)
    result = parser.parse

    assert result.present?
    # Keys should be normalized to strings
    assert_equal "action", result[:steps][0]['type']
  end

  test "yaml parser rejects invalid YAML syntax" do
    content = "title: [invalid\nyaml: syntax"

    parser = WorkflowParsers::YamlParser.new(content)
    result = parser.parse

    assert_nil result
    assert parser.errors.any? { |e| e.downcase.include?("yaml") }
  end

  # ============================================================================
  # CSV Parser Tests
  # ============================================================================

  test "csv parser parses valid CSV with transitions" do
    content = <<~CSV
      workflow_title,id,type,title,question,instructions,transitions,resolution_type
      Test Workflow,step-1,question,Get Name,What is your name?,,step-2,
      ,step-2,action,Process,,Do something,step-3,
      ,step-3,resolve,Complete,,,,success
    CSV

    parser = WorkflowParsers::CsvParser.new(content)
    result = parser.parse

    assert result.present?, "Parser should return result. Errors: #{parser.errors.inspect}"
    assert_equal "Test Workflow", result[:title]
    assert_equal 3, result[:steps].length

    # Check transitions were parsed
    first_step = result[:steps].find { |s| s['title'] == 'Get Name' }
    assert first_step['transitions'].present?, "Question step should have transitions"
  end

  test "csv parser parses conditional transitions" do
    content = <<~CSV
      id,type,title,question,transitions
      step-1,decision,Check,,"step-2:answer == 'yes';step-3:answer != 'yes'"
      step-2,action,Yes Path,,"step-4"
      step-3,action,No Path,,"step-4"
      step-4,resolve,End,,
    CSV

    parser = WorkflowParsers::CsvParser.new(content)
    result = parser.parse

    assert result.present?
    decision_step = result[:steps].find { |s| s['type'] == 'decision' }
    assert_equal 2, decision_step['transitions'].length
    assert decision_step['transitions'].any? { |t| t['condition']&.include?("answer == 'yes'") }
  end

  test "csv parser requires type and title columns" do
    content = <<~CSV
      id,question,instructions
      step-1,What?,Do it
    CSV

    parser = WorkflowParsers::CsvParser.new(content)
    result = parser.parse

    assert_nil result
    assert parser.errors.any? { |e| e.include?("Missing required columns") }
  end

  test "csv parser handles JSON transitions in column" do
    content = <<~CSV
      id,type,title,transitions
      step-1,question,Q1,"[{""target_uuid"":""step-2"",""condition"":""x==1""}]"
      step-2,resolve,End,
    CSV

    parser = WorkflowParsers::CsvParser.new(content)
    result = parser.parse

    assert result.present?
    first_step = result[:steps].first
    assert_equal "step-2", first_step['transitions'].first['target_uuid']
  end

  # ============================================================================
  # Markdown Parser Tests
  # ============================================================================

  test "markdown parser parses step headers" do
    content = <<~MD
      # Markdown Workflow

      A test workflow.

      ## Step 1: Get Name
      Type: question
      Question: What is your name?
      Variable: customer_name

      ## Step 2: Process
      Type: action
      Instructions: Process the data
    MD

    parser = WorkflowParsers::MarkdownParser.new(content)
    result = parser.parse

    assert result.present?
    assert_equal "Markdown Workflow", result[:title]
    assert_equal 2, result[:steps].length
    assert_equal "question", result[:steps][0]['type']
  end

  test "markdown parser extracts frontmatter" do
    content = <<~MD
      ---
      title: "Frontmatter Title"
      description: "From frontmatter"
      ---

      ## Step 1: Action
      Type: action
      Instructions: Do something
    MD

    parser = WorkflowParsers::MarkdownParser.new(content)
    result = parser.parse

    assert result.present?
    assert_equal "Frontmatter Title", result[:title]
  end

  test "markdown parser parses transitions field" do
    content = <<~MD
      # Workflow With Transitions

      ## Step 1: Question
      Type: question
      Question: Name?
      Transitions: Step 2

      ## Step 2: Process
      Type: action
      Instructions: Do it
      Transitions: Step 3

      ## Step 3: End
      Type: resolve
      Resolution Type: success
    MD

    parser = WorkflowParsers::MarkdownParser.new(content)
    result = parser.parse

    assert result.present?
    first_step = result[:steps].find { |s| s['title'].include?('Question') }
    assert first_step['transitions'].present?, "Should have transitions from markdown"
  end

  test "markdown parser handles decision with if true/false" do
    content = <<~MD
      # Decision Workflow

      ## Step 1: Check
      Type: decision
      Condition: answer == 'yes'
      If true: Step 2
      If false: Step 3

      ## Step 2: Yes Path
      Type: action
      Instructions: Do yes

      ## Step 3: No Path
      Type: action
      Instructions: Do no
    MD

    parser = WorkflowParsers::MarkdownParser.new(content)
    result = parser.parse

    assert result.present?
    decision_step = result[:steps].find { |s| s['type'] == 'decision' }
    assert decision_step['branches'].present? || decision_step['transitions'].present?,
           "Decision should have branches or transitions"
  end

  test "markdown parser handles new step types" do
    content = <<~MD
      # New Step Types

      ## Step 1: Show Message
      Type: message
      Content: Welcome to the workflow

      ## Step 2: Escalate
      Type: escalate
      Target Type: team
      Priority: high
      Reason: Customer needs help

      ## Step 3: Resolve
      Type: resolve
      Resolution Type: success
      Resolution Notes: Completed successfully
    MD

    parser = WorkflowParsers::MarkdownParser.new(content)
    result = parser.parse

    assert result.present?
    assert_equal 3, result[:steps].length
    assert_equal "message", result[:steps][0]['type']
    assert_equal "escalate", result[:steps][1]['type']
    assert_equal "resolve", result[:steps][2]['type']
    assert_equal "team", result[:steps][1]['target_type']
    assert_equal "high", result[:steps][1]['priority']
  end

  test "markdown parser parses options for multiple choice questions" do
    content = <<~MD
      # Workflow With Options

      ## Step 1: Select Issue Type
      Type: question
      Question: What type of issue?
      Answer Type: multiple_choice
      Variable: issue_type
      Options: Billing:billing, Technical:technical, Other:other
      Transitions: Step 2

      ## Step 2: Done
      Type: resolve
      Resolution Type: success
    MD

    parser = WorkflowParsers::MarkdownParser.new(content)
    result = parser.parse

    assert result.present?
    question_step = result[:steps].find { |s| s['type'] == 'question' }

    assert question_step['options'].present?, "Question step should have options"
    assert_equal 3, question_step['options'].length

    billing_opt = question_step['options'].find { |o| o['value'] == 'billing' }
    assert billing_opt.present?
    assert_equal "Billing", billing_opt['label']
  end

  # ============================================================================
  # Normalization Tests
  # ============================================================================

  test "normalizes all imported steps to have IDs" do
    content = {
      title: "No IDs Workflow",
      steps: [
        { type: "question", title: "Q1", question: "Name?" },
        { type: "action", title: "A1", instructions: "Do it" }
      ]
    }.to_json

    parser = WorkflowParsers::JsonParser.new(content)
    result = parser.parse

    result[:steps].each do |step|
      assert step['id'].present?, "Step '#{step['title']}' should have an ID"
    end
  end

  test "marks incomplete steps during import" do
    content = {
      title: "Incomplete Steps",
      steps: [
        { type: "question", title: "Missing Question" }, # No question field
        { type: "action", title: "Complete Action", instructions: "Do this" }
      ]
    }.to_json

    parser = WorkflowParsers::JsonParser.new(content)
    result = parser.parse

    incomplete_step = result[:steps].find { |s| s['title'] == "Missing Question" }
    complete_step = result[:steps].find { |s| s['title'] == "Complete Action" }

    assert incomplete_step['_import_incomplete'], "Question without question text should be incomplete"
    assert_not complete_step['_import_incomplete'], "Action with instructions should be complete"
  end
end
