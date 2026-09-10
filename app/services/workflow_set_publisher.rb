# Publishes a workflow together with every draft it depends on.
#
# Workflow#validate_subflow_steps requires a sub-flow target to be published
# already. Its strategy — publish the leaves first — is undefined on a cycle:
# whichever member you publish first still points at a draft. Measured on real
# data, three mutually-referencing groups had no valid publish order at all.
#
# So the set publishes at once. Every member carries the set's ids in
# `publishing_alongside`, which the validation accepts in place of "already
# published", and the whole thing is one transaction. The rule is not weakened:
# by commit, every target really is published.
class WorkflowSetPublisher
  Result = Data.define(:workflows, :error, :failed_workflow) do
    def success?
      error.nil?
    end
  end

  def self.publish(root, user, changelog: nil)
    new(root, user, changelog:).publish
  end

  # For callers that want to show the set before committing to it.
  def self.closure_for(root)
    new(root, nil).closure
  end

  def initialize(root, user, changelog: nil)
    @root = root
    @user = user
    @changelog = changelog
  end

  # The root plus every DRAFT workflow reachable from it through sub_flow steps.
  #
  # A published target stops the walk: it already satisfies the rule, and its own
  # targets were checked when it published. Following it would drag unrelated
  # workflows into the set.
  def closure
    members = { @root.id => @root }
    queue = [@root]

    until queue.empty?
      current = queue.shift
      target_ids(current).each do |id|
        next if members.key?(id)

        target = Workflow.find_by(id: id)
        next unless target&.draft?

        members[id] = target
        queue << target
      end
    end

    members.values
  end

  def publish
    members = closure

    unauthorized = members.reject { |workflow| workflow.can_be_edited_by?(@user) }
    if unauthorized.any?
      return failure("You do not have permission to publish '#{unauthorized.first.title}'.",
                     unauthorized.first)
    end

    # Checked across the whole set before anything is written, so one refusal
    # names every member still waiting for an audience rather than the first.
    without_audience = members.reject { it.group_workflows.exists? }
    if without_audience.any?
      titles = without_audience.map { it.title.inspect }.to_sentence
      return failure("Choose who can see #{titles} before publishing: pick at least one group in Details, " \
                     "or Global for everyone signed in.", without_audience.first)
    end

    ids = members.to_set(&:id)
    outcome = nil

    Workflow.transaction do
      members.each do |workflow|
        workflow.publishing_alongside = ids
        result = WorkflowPublisher.publish(workflow, @user, changelog: @changelog)
        next if result.success?

        outcome = failure("#{workflow.title}: #{result.error}", workflow)
        raise ActiveRecord::Rollback
      end
    end

    outcome || Result.new(workflows: members, error: nil, failed_workflow: nil)
  end

  private

  def failure(message, workflow)
    Result.new(workflows: [], error: message, failed_workflow: workflow)
  end

  def target_ids(workflow)
    Steps::SubFlow.where(workflow_id: workflow.id)
                  .where.not(sub_flow_workflow_id: nil)
                  .distinct
                  .pluck(:sub_flow_workflow_id)
  end
end
