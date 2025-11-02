# Seeds file for Kizuflow

# Post-onboarding checklist template
post_onboarding = Template.find_or_create_by!(name: "Post-Onboarding Checklist") do |t|
  t.description = "A comprehensive checklist for onboarding new clients after initial setup"
  t.category = "post-onboarding"
  t.is_public = true
  t.workflow_data = [
    {"type" => "question", "title" => "Account Setup Complete?", "description" => "Verify that the client's account has been fully set up", "question" => "Is the account setup complete?", "answer_type" => "yes_no"},
    {"type" => "action", "title" => "Send Welcome Email", "description" => "Send welcome email to the client", "action_type" => "email", "instructions" => "Send the standard welcome email template"}
  ]
end

# Troubleshooting decision tree template
troubleshooting = Template.find_or_create_by!(name: "Troubleshooting Decision Tree") do |t|
  t.description = "A structured decision tree for troubleshooting common client issues"
  t.category = "troubleshooting"
  t.is_public = true
  t.workflow_data = [
    {"type" => "question", "title" => "What is the issue?", "description" => "Categorize the client's reported issue", "question" => "Select the type of issue:", "answer_type" => "multiple_choice"},
    {"type" => "action", "title" => "Document Issue", "description" => "Document the issue details", "action_type" => "documentation", "instructions" => "Record all relevant details about the issue"}
  ]
end

# Basic client training flow template
training = Template.find_or_create_by!(name: "Basic Client Training Flow") do |t|
  t.description = "A basic workflow for training new clients on core features"
  t.category = "training"
  t.is_public = true
  t.workflow_data = [
    {"type" => "action", "title" => "Introduction", "description" => "Welcome the client", "action_type" => "presentation", "instructions" => "Introduce yourself and explain the training"},
    {"type" => "question", "title" => "Previous Experience", "description" => "Understand the client's prior experience", "question" => "What is your experience level?", "answer_type" => "multiple_choice"}
  ]
end
