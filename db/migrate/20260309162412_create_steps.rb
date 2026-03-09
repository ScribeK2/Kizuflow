class CreateSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :steps do |t|
      t.references :workflow, null: false, foreign_key: true
      t.string     :type, null: false        # STI: Steps::Question, Steps::Action, etc.
      t.string     :uuid, null: false        # External identity for import/export
      t.string     :title
      t.integer    :position, null: false

      # Question-specific
      t.string     :question
      t.string     :answer_type
      t.string     :variable_name
      t.json       :options                  # Answer options array

      # Action/Message shared
      t.boolean    :can_resolve, default: false

      # Action-specific
      t.string     :action_type
      t.json      :output_fields            # Output field definitions
      t.json      :jumps                    # Universal jumps

      # Escalate-specific
      t.string     :target_type
      t.string     :target_value
      t.string     :priority
      t.boolean    :reason_required, default: false

      # Resolve-specific
      t.string     :resolution_type
      t.string     :resolution_code
      t.boolean    :notes_required, default: false
      t.boolean    :survey_trigger, default: false

      # SubFlow-specific
      t.integer    :sub_flow_workflow_id
      t.json      :variable_mapping         # Parent-child variable mapping

      t.timestamps
    end

    add_index :steps, [:workflow_id, :position]
    add_index :steps, :uuid, unique: true
    add_index :steps, :type  # STI index
    add_index :steps, :sub_flow_workflow_id
  end
end
