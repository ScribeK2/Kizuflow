# StepTemplate - Predefined step templates for quick insertion
# These are common step configurations that users can quickly apply
class StepTemplate
  TEMPLATES = {
    question: {
      "simple_yes_no" => {
        name: "Simple Yes/No Question",
        type: "question",
        title: "Yes or No?",
        description: "Ask a yes/no question",
        question: "Is this correct?",
        answer_type: "yes_no",
        variable_name: "answer"
      },
      "text_input" => {
        name: "Text Input",
        type: "question",
        title: "Enter Information",
        description: "Collect text input from user",
        question: "Please enter the value:",
        answer_type: "text",
        variable_name: "user_input"
      },
      "multiple_choice" => {
        name: "Multiple Choice",
        type: "question",
        title: "Select an Option",
        description: "Choose from predefined options",
        question: "Which option do you prefer?",
        answer_type: "multiple_choice",
        variable_name: "selection"
      }
    }
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
    template = TEMPLATES.dig(type.to_sym, key.to_s)
    template ? { key: key.to_s, **template } : nil
  end
end
