class WorkflowImporter
  Result = Struct.new(:success, :workflow, :errors, :warnings, :incomplete_steps_count, keyword_init: true) do
    def success? = success
    def incomplete_steps? = incomplete_steps_count.to_i > 0
  end

  def initialize(user, format:, content:)
    @user = user
    @format = format.to_sym
    @content = content
  end

  def call
    parser = create_parser

    workflow_data = parser.parse

    unless workflow_data
      parse_errors = parser.errors.any? ? parser.errors : ["Failed to parse file"]
      return failure(parse_errors, warnings: parser.warnings)
    end

    workflow = @user.workflows.build(
      title: workflow_data[:title],
      description: workflow_data[:description] || "",
      steps: workflow_data[:steps] || [],
      graph_mode: workflow_data[:graph_mode] != false,
      start_node_uuid: workflow_data[:start_node_uuid] || workflow_data[:steps]&.first&.dig('id'),
      is_public: false,
      status: 'published'
    )

    incomplete_count = (workflow_data[:steps] || []).count { |step| step['_import_incomplete'] }

    warnings = parser.warnings.dup
    warnings.concat(validate_imported_graph(workflow)) if workflow.graph_mode?

    if workflow.save
      Result.new(
        success: true,
        workflow: workflow,
        errors: [],
        warnings: warnings,
        incomplete_steps_count: incomplete_count
      )
    else
      Result.new(
        success: false,
        workflow: workflow,
        errors: workflow.errors.full_messages,
        warnings: warnings,
        incomplete_steps_count: incomplete_count
      )
    end
  rescue StandardError => e
    failure([e.message])
  end

  private

  def create_parser
    case @format
    when :json     then WorkflowParsers::JsonParser.new(@content)
    when :csv      then WorkflowParsers::CsvParser.new(@content)
    when :yaml     then WorkflowParsers::YamlParser.new(@content)
    when :markdown then WorkflowParsers::MarkdownParser.new(@content)
    else raise ArgumentError, "Unsupported format: #{@format}"
    end
  end

  def validate_imported_graph(workflow)
    errors = []
    return errors unless workflow.steps.present?

    graph_steps = workflow.steps.each_with_object({}) do |step, hash|
      hash[step['id']] = step if step.is_a?(Hash) && step['id']
    end

    start_uuid = workflow.start_node_uuid || workflow.steps.first&.dig('id')

    validator = GraphValidator.new(graph_steps, start_uuid)
    unless validator.valid?
      validator.errors.each { |e| errors << "Graph validation: #{e}" }
    end

    errors
  rescue NameError
    []
  end

  def failure(errors, warnings: [])
    Result.new(
      success: false,
      workflow: nil,
      errors: errors,
      warnings: warnings,
      incomplete_steps_count: 0
    )
  end
end
