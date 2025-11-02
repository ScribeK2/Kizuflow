# StepTemplate - Predefined step templates for quick insertion
# These are common step configurations that users can quickly apply
class StepTemplate
  TEMPLATES = {
    question: {
      "yes_no_confirmation" => {
        name: "Yes/No Confirmation",
        type: "question",
        title: "Confirmation",
        description: "Ask for user confirmation",
        question: "Do you confirm?",
        answer_type: "yes_no"
      },
      "text_input" => {
        name: "Text Input",
        type: "question",
        title: "Text Input",
        description: "Collect text input from user",
        question: "Enter your response:",
        answer_type: "text"
      },
      "email_collection" => {
        name: "Email Collection",
        type: "question",
        title: "Email Address",
        description: "Collect user's email address",
        question: "What is your email address?",
        answer_type: "text",
        variable_name: "email"
      },
      "name_collection" => {
        name: "Name Collection",
        type: "question",
        title: "Full Name",
        description: "Collect user's full name",
        question: "What is your full name?",
        answer_type: "text",
        variable_name: "user_name"
      },
      "age_collection" => {
        name: "Age Collection",
        type: "question",
        title: "Age",
        description: "Collect user's age",
        question: "What is your age?",
        answer_type: "number",
        variable_name: "age"
      },
      "multiple_choice_selection" => {
        name: "Multiple Choice Selection",
        type: "question",
        title: "Select Option",
        description: "Choose from multiple options",
        question: "Please select an option:",
        answer_type: "multiple_choice",
        options: [
          { label: "Option 1", value: "option1" },
          { label: "Option 2", value: "option2" },
          { label: "Option 3", value: "option3" }
        ]
      },
      "date_selection" => {
        name: "Date Selection",
        type: "question",
        title: "Select Date",
        description: "Choose a date",
        question: "What date would you prefer?",
        answer_type: "date"
      }
    },
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
    action: {
      "send_email" => {
        name: "Send Email",
        type: "action",
        title: "Send Email",
        description: "Send an email notification",
        action_type: "email",
        instructions: "Send email to the user"
      },
      "display_message" => {
        name: "Display Message",
        type: "action",
        title: "Show Message",
        description: "Display a message to the user",
        action_type: "message",
        instructions: "Display this message to the user"
      },
      "create_record" => {
        name: "Create Record",
        type: "action",
        title: "Create Record",
        description: "Create a new record",
        action_type: "create",
        instructions: "Create a new record in the system"
      },
      "update_status" => {
        name: "Update Status",
        type: "action",
        title: "Update Status",
        description: "Update the status",
        action_type: "update",
        instructions: "Update the current status"
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
    template = TEMPLATES.dig(type.to_sym, key.to_sym)
    template ? { key: key.to_s, **template } : nil
  end
end

