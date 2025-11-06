class AssignExistingWorkflowsToUncategorizedGroup < ActiveRecord::Migration[8.0]
  def up
    # Ensure Uncategorized group exists
    uncategorized_group = Group.find_or_create_by!(name: "Uncategorized") do |group|
      group.description = "Default group for workflows without explicit group assignment"
      group.position = 0
    end

    # Assign all workflows without group assignments to Uncategorized
    workflows_without_groups = Workflow.left_joins(:group_workflows)
                                       .where(group_workflows: { id: nil })
    
    workflows_without_groups.find_each do |workflow|
      GroupWorkflow.find_or_create_by!(
        workflow: workflow,
        group: uncategorized_group,
        is_primary: true
      )
    end

    puts "Assigned #{workflows_without_groups.count} workflows to Uncategorized group"
  end

  def down
    # Remove Uncategorized group assignments (but keep the workflows)
    uncategorized_group = Group.find_by(name: "Uncategorized")
    return unless uncategorized_group

    GroupWorkflow.where(group: uncategorized_group).destroy_all
  end
end
