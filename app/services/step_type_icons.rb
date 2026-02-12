# Single source of truth for step type icon mappings.
# Used by WorkflowsHelper (views) and Workflow model.
module StepTypeIcons
  ICONS = {
    'question' => '?',
    'decision' => '/',
    'action' => '!',
    'checkpoint' => 'v',
    'sub_flow' => '~',
    'message' => 'm',
    'escalate' => '^',
    'resolve' => 'r'
  }.freeze

  DEFAULT_ICON = '#'

  def step_type_icon(type)
    ICONS.fetch(type, DEFAULT_ICON)
  end
end
