# StepTemplate - Predefined step templates for quick insertion
# These are common step configurations that users can quickly apply
class StepTemplate
  TEMPLATES = {
    decision: {
      "simple_yes_no" => {
        name: "Simple Yes/No Decision",
        type: "decision",
        title: "Decision Point",
        description: "Branch based on yes/no answer",
        condition: "answer == 'yes'"
      },
      "variable_check" => {
        name: "Variable Check",
        type: "decision",
        title: "Check Variable",
        description: "Check a variable value",
        condition: "variable_name == 'value'"
      },
      "age_threshold" => {
        name: "Age Threshold",
        type: "decision",
        title: "Age Check",
        description: "Check if age meets threshold",
        condition: "age >= 18"
      }
    },
  }.freeze

  def self.for_type(type)
    TEMPLATES[type.to_sym] || {}
  end

  def self.all_for_type(type)
    for_type(type).map do |key, template|
      { key: key.to_s, **template }
    end
  end

  def self.find(type, key)
    template = TEMPLATES.dig(type.to_sym, key.to_sym)
    template ? { key: key.to_s, **template } : nil
  end
end
