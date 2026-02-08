# Seeds file for Kizuflow

# Create demo admin user for Render deployment
admin_user = User.find_or_initialize_by(email: "admin@test.com")
if admin_user.new_record?
  admin_user.password = "TestAdmin123!"
  admin_user.password_confirmation = "TestAdmin123!"
  admin_user.role = "admin"
  admin_user.save!
  puts "Created admin user: admin@test.com"
else
  # Update existing user to ensure they're an admin (only update role, not password)
  admin_user.update!(role: "admin")
  puts "Updated user to admin: admin@test.com"
end

# ============================================================================
# TEMPLATE LIBRARY - Pre-built workflow templates (Graph Mode)
# ============================================================================
# These templates provide starting points for common business workflows.
# Users can duplicate these and customize them for their specific needs.
# All templates use graph mode with explicit transitions between steps.
# Step types: question, action, message, escalate, resolve
# ============================================================================

# --- Template 1: Email Troubleshooting ---
# Pre-generate UUIDs so transitions can reference other steps
et_welcome = SecureRandom.uuid
et_email_client = SecureRandom.uuid
et_issue_type = SecureRandom.uuid
et_fix_auth = SecureRandom.uuid
et_fix_timeout = SecureRandom.uuid
et_fix_cert = SecureRandom.uuid
et_fix_sync = SecureRandom.uuid
et_general = SecureRandom.uuid
et_resolved_q = SecureRandom.uuid
et_resolution = SecureRandom.uuid
et_escalate = SecureRandom.uuid
et_escalate_resolve = SecureRandom.uuid

Template.find_or_initialize_by(name: "Email Troubleshooting").update!(
  description: "A streamlined workflow for diagnosing and resolving email connectivity issues across common clients and devices. Perfect for customer support teams.",
  category: "troubleshooting",
  is_public: true,
  workflow_data: [
    {
      "id" => et_welcome,
      "type" => "message",
      "title" => "Welcome - Email Troubleshooting",
      "description" => "Introduction to email troubleshooting workflow",
      "content" => "This workflow will help diagnose and resolve email connectivity issues. Gather the following information:\n- Email address\n- Email client being used (Gmail, Outlook, Apple Mail)\n- Device type (Windows, Mac, iOS, Android)\n- Error messages (if any)",
      "transitions" => [{"target_uuid" => et_email_client}]
    },
    {
      "id" => et_email_client,
      "type" => "question",
      "title" => "Select Email Client",
      "description" => "Identify which email client is experiencing issues",
      "question" => "Which email client is the user trying to configure?",
      "answer_type" => "single_choice",
      "variable_name" => "email_client",
      "options" => [
        {"label" => "Gmail (App or Web)", "value" => "gmail"},
        {"label" => "Microsoft Outlook", "value" => "outlook"},
        {"label" => "Apple Mail", "value" => "apple_mail"},
        {"label" => "Other", "value" => "other"}
      ],
      "transitions" => [{"target_uuid" => et_issue_type}]
    },
    {
      "id" => et_issue_type,
      "type" => "question",
      "title" => "Identify Issue Type",
      "description" => "Categorize the specific problem",
      "question" => "What type of error or issue is the user experiencing?",
      "answer_type" => "single_choice",
      "variable_name" => "issue_type",
      "options" => [
        {"label" => "Authentication Error / Invalid Password", "value" => "auth_error"},
        {"label" => "Connection Timeout / Server Not Found", "value" => "timeout"},
        {"label" => "Certificate Error / SSL Warning", "value" => "certificate"},
        {"label" => "Sync Problems / Missing Emails", "value" => "sync"},
        {"label" => "Other Issue", "value" => "other"}
      ],
      "transitions" => [
        {"target_uuid" => et_fix_auth, "condition" => "issue_type == 'auth_error'", "label" => "Authentication Error"},
        {"target_uuid" => et_fix_timeout, "condition" => "issue_type == 'timeout'", "label" => "Connection Timeout"},
        {"target_uuid" => et_fix_cert, "condition" => "issue_type == 'certificate'", "label" => "Certificate Error"},
        {"target_uuid" => et_fix_sync, "condition" => "issue_type == 'sync'", "label" => "Sync Problems"},
        {"target_uuid" => et_general, "label" => "Other Issue"}
      ]
    },
    {
      "id" => et_fix_auth,
      "type" => "action",
      "title" => "Fix Authentication Error",
      "description" => "Steps to resolve authentication/password errors",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Incorrect password\n2. Wrong username format (use full email address)\n3. 2FA enabled without app password\n4. OAuth required (2026 update)\n\n**Solution Steps:**\n1. Verify password by logging into webmail\n2. Ensure username is the full email address (user@domain.com)\n3. If 2FA is enabled, generate an App Password from provider settings\n4. For Microsoft/Google: Try OAuth authentication if available",
      "transitions" => [{"target_uuid" => et_resolved_q}]
    },
    {
      "id" => et_fix_timeout,
      "type" => "action",
      "title" => "Fix Connection Timeout",
      "description" => "Steps to resolve connection and server issues",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Incorrect server address\n2. Wrong port number\n3. Firewall blocking connection\n4. Network issues\n\n**Solution Steps:**\n1. Verify server addresses:\n   - IMAP: imap.domain.com or mail.domain.com\n   - SMTP: smtp.domain.com or mail.domain.com\n2. Verify ports:\n   - IMAP: 993 (SSL/TLS)\n   - SMTP: 465 (SSL) or 587 (STARTTLS)\n3. Check network connection and disable VPN if needed\n4. Try connecting from a different network",
      "transitions" => [{"target_uuid" => et_resolved_q}]
    },
    {
      "id" => et_fix_cert,
      "type" => "action",
      "title" => "Fix Certificate Error",
      "description" => "Steps to resolve SSL/TLS certificate issues",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Expired SSL certificate\n2. Incorrect device date/time\n3. Certificate hostname mismatch\n\n**Solution Steps:**\n1. **Check device date/time** - Ensure it's set correctly (this is the most common cause)\n2. Verify security settings match port:\n   - Port 993 requires SSL/TLS\n   - Port 587 requires STARTTLS\n3. Try alternate server address if available\n4. If certificate is genuinely expired, contact email provider",
      "transitions" => [{"target_uuid" => et_resolved_q}]
    },
    {
      "id" => et_fix_sync,
      "type" => "action",
      "title" => "Fix Sync Problems",
      "description" => "Steps to resolve email synchronization issues",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Using POP instead of IMAP\n2. Sync settings too restrictive\n3. Storage quota exceeded\n\n**Solution Steps:**\n1. Verify using IMAP (not POP) for multi-device sync\n2. Check sync settings:\n   - iOS: Settings > Mail > Accounts > Mail Days to Sync\n   - Android: Gmail Settings > Days of mail to sync\n3. Check storage quota in webmail\n4. Remove and re-add account to clear local cache",
      "transitions" => [{"target_uuid" => et_resolved_q}]
    },
    {
      "id" => et_general,
      "type" => "action",
      "title" => "General Troubleshooting",
      "description" => "General troubleshooting steps for other issues",
      "action_type" => "instructions",
      "instructions" => "**General Troubleshooting Steps:**\n1. Remove and re-add the email account\n2. Update email client to latest version\n3. Check provider's status page for outages\n4. Try a different email client temporarily\n5. Contact email provider support if issue persists",
      "transitions" => [{"target_uuid" => et_resolved_q}]
    },
    {
      "id" => et_resolved_q,
      "type" => "question",
      "title" => "Issue Resolved?",
      "description" => "Verify if the troubleshooting steps resolved the issue",
      "question" => "Was the issue resolved after following the troubleshooting steps?",
      "answer_type" => "yes_no",
      "variable_name" => "issue_resolved",
      "transitions" => [
        {"target_uuid" => et_resolution, "condition" => "issue_resolved == 'yes'", "label" => "Resolved"},
        {"target_uuid" => et_escalate, "condition" => "issue_resolved == 'no'", "label" => "Not Resolved"}
      ]
    },
    {
      "id" => et_resolution,
      "type" => "resolve",
      "title" => "Issue Resolved",
      "description" => "Troubleshooting completed successfully",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => et_escalate,
      "type" => "escalate",
      "title" => "Escalate to Technical Support",
      "description" => "Escalate unresolved issues to technical support",
      "target_type" => "department",
      "target_value" => "Technical Support",
      "priority" => "high",
      "reason_required" => true,
      "notes" => "Include: Email client ({{email_client}}), Issue type ({{issue_type}}), exact error messages, and steps already attempted.",
      "transitions" => [{"target_uuid" => et_escalate_resolve}]
    },
    {
      "id" => et_escalate_resolve,
      "type" => "resolve",
      "title" => "Escalation Complete",
      "description" => "Issue has been escalated to technical support for further investigation",
      "resolution_type" => "escalated",
      "transitions" => []
    }
  ]
)

# --- Template 2: Refund Process ---
rp_welcome = SecureRandom.uuid
rp_order = SecureRandom.uuid
rp_date = SecureRandom.uuid
rp_reason = SecureRandom.uuid
rp_return_window = SecureRandom.uuid
rp_approve = SecureRandom.uuid
rp_process = SecureRandom.uuid
rp_notify = SecureRandom.uuid
rp_complete = SecureRandom.uuid
rp_deny = SecureRandom.uuid
rp_denied_resolve = SecureRandom.uuid
rp_review = SecureRandom.uuid
rp_review_resolve = SecureRandom.uuid

Template.find_or_initialize_by(name: "Refund Process").update!(
  description: "A systematic workflow for processing customer refunds with verification, approval, and documentation steps. Ensures consistent handling of refund requests.",
  category: "customer-service",
  is_public: true,
  workflow_data: [
    {
      "id" => rp_welcome,
      "type" => "message",
      "title" => "Refund Request Received",
      "description" => "Initial notification of refund request",
      "content" => "**Refund Process Initiated**\n\nA customer has requested a refund. This workflow will guide you through:\n1. Verifying the purchase\n2. Checking refund eligibility\n3. Processing approval\n4. Initiating refund\n5. Notifying customer\n\nGather: Order number, customer email, purchase date, reason for refund.",
      "transitions" => [{"target_uuid" => rp_order}]
    },
    {
      "id" => rp_order,
      "type" => "question",
      "title" => "Order Verification",
      "description" => "Verify the order exists and is valid",
      "question" => "What is the order number or transaction ID?",
      "answer_type" => "text",
      "variable_name" => "order_number",
      "transitions" => [{"target_uuid" => rp_date}]
    },
    {
      "id" => rp_date,
      "type" => "question",
      "title" => "Purchase Date",
      "description" => "Determine when the purchase was made",
      "question" => "When was the purchase made? (or enter 'recent' if within last 30 days)",
      "answer_type" => "text",
      "variable_name" => "purchase_date",
      "transitions" => [{"target_uuid" => rp_reason}]
    },
    {
      "id" => rp_reason,
      "type" => "question",
      "title" => "Refund Reason",
      "description" => "Categorize the reason for refund request",
      "question" => "What is the reason for the refund request?",
      "answer_type" => "single_choice",
      "variable_name" => "refund_reason",
      "options" => [
        {"label" => "Defective Product", "value" => "defective"},
        {"label" => "Not as Described", "value" => "not_as_described"},
        {"label" => "Customer Changed Mind", "value" => "changed_mind"},
        {"label" => "Duplicate Purchase", "value" => "duplicate"},
        {"label" => "Other", "value" => "other"}
      ],
      "transitions" => [
        {"target_uuid" => rp_approve, "condition" => "refund_reason == 'defective'", "label" => "Defective"},
        {"target_uuid" => rp_approve, "condition" => "refund_reason == 'not_as_described'", "label" => "Not as Described"},
        {"target_uuid" => rp_approve, "condition" => "refund_reason == 'duplicate'", "label" => "Duplicate"},
        {"target_uuid" => rp_return_window, "condition" => "refund_reason == 'changed_mind'", "label" => "Changed Mind"},
        {"target_uuid" => rp_review, "label" => "Other"}
      ]
    },
    {
      "id" => rp_return_window,
      "type" => "question",
      "title" => "Check Return Window",
      "description" => "Verify if purchase is within return window",
      "question" => "Is the purchase within the 30-day return window?",
      "answer_type" => "yes_no",
      "variable_name" => "within_window",
      "transitions" => [
        {"target_uuid" => rp_approve, "condition" => "within_window == 'yes'", "label" => "Within Window"},
        {"target_uuid" => rp_deny, "condition" => "within_window == 'no'", "label" => "Outside Window"}
      ]
    },
    {
      "id" => rp_approve,
      "type" => "action",
      "title" => "Approve Refund",
      "description" => "Process the approved refund",
      "action_type" => "instructions",
      "instructions" => "**Refund Approved**\n\nProceed with refund:\n1. Verify payment method (original payment source)\n2. Process refund through payment gateway\n3. Note refund amount (check original transaction)\n4. Record refund ID/confirmation number\n5. Document: Order {{order_number}}, Reason: {{refund_reason}}\n\nRefund typically processes within 5-10 business days.",
      "transitions" => [{"target_uuid" => rp_process}]
    },
    {
      "id" => rp_process,
      "type" => "action",
      "title" => "Process Refund Payment",
      "description" => "Execute the refund transaction",
      "action_type" => "instructions",
      "instructions" => "**Processing Refund**\n\n1. Log into payment gateway\n2. Locate transaction: {{order_number}}\n3. Initiate refund (full or partial as applicable)\n4. Copy refund confirmation/transaction ID\n5. Update order status to 'Refunded' in system",
      "transitions" => [{"target_uuid" => rp_notify}]
    },
    {
      "id" => rp_notify,
      "type" => "message",
      "title" => "Notify Customer",
      "description" => "Send confirmation to customer",
      "content" => "**Customer Notification**\n\nSend email to customer:\n\nSubject: Refund Processed - Order {{order_number}}\n\nBody:\n- Confirm refund has been processed\n- Refund amount and method\n- Expected processing time (5-10 business days)\n- Refund confirmation ID\n- Thank customer for their patience",
      "transitions" => [{"target_uuid" => rp_complete}]
    },
    {
      "id" => rp_complete,
      "type" => "resolve",
      "title" => "Refund Complete",
      "description" => "Refund has been processed and customer notified",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => rp_deny,
      "type" => "message",
      "title" => "Deny Refund - Outside Window",
      "description" => "Handle refund denial for purchases outside return window",
      "content" => "**Refund Denied - Outside Return Window**\n\nPurchase date: {{purchase_date}}\n\nSend polite denial email:\n- Explain return policy (30-day window)\n- Offer alternative: Store credit or exchange (if applicable)\n- Apologize for any inconvenience\n- Provide contact for further questions",
      "transitions" => [{"target_uuid" => rp_denied_resolve}]
    },
    {
      "id" => rp_denied_resolve,
      "type" => "resolve",
      "title" => "Refund Denied",
      "description" => "Refund request denied - outside return window",
      "resolution_type" => "failure",
      "transitions" => []
    },
    {
      "id" => rp_review,
      "type" => "escalate",
      "title" => "Escalate for Review",
      "description" => "Manual review required for special cases",
      "target_type" => "supervisor",
      "target_value" => "Refund Review Team",
      "priority" => "medium",
      "reason_required" => true,
      "notes" => "Order: {{order_number}}, Reason: {{refund_reason}}. Include customer communication history and all case details. Follow up within 24-48 hours.",
      "transitions" => [{"target_uuid" => rp_review_resolve}]
    },
    {
      "id" => rp_review_resolve,
      "type" => "resolve",
      "title" => "Under Review",
      "description" => "Case has been escalated for supervisor review",
      "resolution_type" => "escalated",
      "transitions" => []
    }
  ]
)

# --- Template 3: Customer Onboarding ---
co_welcome = SecureRandom.uuid
co_name = SecureRandom.uuid
co_company = SecureRandom.uuid
co_usecase = SecureRandom.uuid
co_experience = SecureRandom.uuid
co_beginner = SecureRandom.uuid
co_intermediate = SecureRandom.uuid
co_advanced = SecureRandom.uuid
co_verify = SecureRandom.uuid
co_complete = SecureRandom.uuid

Template.find_or_initialize_by(name: "Customer Onboarding").update!(
  description: "A comprehensive onboarding workflow to welcome new customers, collect preferences, provide initial setup guidance, and ensure a smooth first experience.",
  category: "onboarding",
  is_public: true,
  workflow_data: [
    {
      "id" => co_welcome,
      "type" => "message",
      "title" => "Welcome New Customer",
      "description" => "Initial welcome message for new customer",
      "content" => "**Welcome!**\n\nThank you for choosing our service. This onboarding process will help you:\n1. Set up your account\n2. Configure preferences\n3. Learn key features\n4. Get started with best practices\n\nThis should take about 10-15 minutes.",
      "transitions" => [{"target_uuid" => co_name}]
    },
    {
      "id" => co_name,
      "type" => "question",
      "title" => "Customer Name",
      "description" => "Collect customer's name for personalization",
      "question" => "What is your full name?",
      "answer_type" => "text",
      "variable_name" => "customer_name",
      "transitions" => [{"target_uuid" => co_company}]
    },
    {
      "id" => co_company,
      "type" => "question",
      "title" => "Company Information",
      "description" => "Optional company details",
      "question" => "What company or organization are you with? (Optional)",
      "answer_type" => "text",
      "variable_name" => "company_name",
      "transitions" => [{"target_uuid" => co_usecase}]
    },
    {
      "id" => co_usecase,
      "type" => "question",
      "title" => "Use Case",
      "description" => "Understand how customer plans to use the service",
      "question" => "What is your primary use case?",
      "answer_type" => "single_choice",
      "variable_name" => "use_case",
      "options" => [
        {"label" => "Personal Use", "value" => "personal"},
        {"label" => "Small Business", "value" => "small_business"},
        {"label" => "Enterprise", "value" => "enterprise"},
        {"label" => "Educational/Non-profit", "value" => "nonprofit"}
      ],
      "transitions" => [{"target_uuid" => co_experience}]
    },
    {
      "id" => co_experience,
      "type" => "question",
      "title" => "Experience Level",
      "description" => "Assess technical familiarity",
      "question" => "How would you rate your experience with similar tools?",
      "answer_type" => "single_choice",
      "variable_name" => "experience_level",
      "options" => [
        {"label" => "Beginner - First time using this type of tool", "value" => "beginner"},
        {"label" => "Intermediate - Some experience", "value" => "intermediate"},
        {"label" => "Advanced - Very familiar with similar tools", "value" => "advanced"}
      ],
      "transitions" => [
        {"target_uuid" => co_beginner, "condition" => "experience_level == 'beginner'", "label" => "Beginner"},
        {"target_uuid" => co_intermediate, "condition" => "experience_level == 'intermediate'", "label" => "Intermediate"},
        {"target_uuid" => co_advanced, "condition" => "experience_level == 'advanced'", "label" => "Advanced"}
      ]
    },
    {
      "id" => co_beginner,
      "type" => "message",
      "title" => "Beginner Setup Guide",
      "description" => "Detailed setup instructions for beginners",
      "content" => "**Welcome, {{customer_name}}!**\n\nLet's get you started step-by-step:\n\n**Step 1: Account Verification**\n- Check your email for verification link\n- Click the link to activate your account\n\n**Step 2: Profile Setup**\n- Complete your profile information\n- Upload a profile picture (optional)\n- Set your timezone\n\n**Step 3: Explore Dashboard**\n- Familiarize yourself with the main dashboard\n- Review the navigation menu\n- Check out the help documentation\n\nTake your time - there's no rush!",
      "transitions" => [{"target_uuid" => co_verify}]
    },
    {
      "id" => co_intermediate,
      "type" => "message",
      "title" => "Intermediate Setup Guide",
      "description" => "Streamlined setup for users with some experience",
      "content" => "**Hello, {{customer_name}}!**\n\nHere's your quick start guide:\n\n**Essential Setup:**\n1. Verify your email address\n2. Complete basic profile information\n3. Review key features in the dashboard\n4. Check out the tutorial videos (optional)\n\n**Recommended Next Steps:**\n- Explore advanced settings\n- Review integration options\n- Set up your first project/workflow\n\nNeed help? Our support team is available!",
      "transitions" => [{"target_uuid" => co_verify}]
    },
    {
      "id" => co_advanced,
      "type" => "message",
      "title" => "Advanced Quick Start",
      "description" => "Minimal setup for experienced users",
      "content" => "**Welcome, {{customer_name}}!**\n\nQuick start for experienced users:\n\n**Essential Only:**\n1. Verify email\n2. Review API documentation (if applicable)\n3. Configure integrations\n\n**Resources:**\n- API docs: /docs/api\n- Advanced features: /features\n- Community forum: /community\n\nYou're all set! Dive right in.",
      "transitions" => [{"target_uuid" => co_verify}]
    },
    {
      "id" => co_verify,
      "type" => "question",
      "title" => "Setup Verification",
      "description" => "Verify user completed initial setup",
      "question" => "Have you completed the initial account setup? (Email verified, profile created)",
      "answer_type" => "yes_no",
      "variable_name" => "setup_complete",
      "transitions" => [{"target_uuid" => co_complete}]
    },
    {
      "id" => co_complete,
      "type" => "resolve",
      "title" => "Onboarding Complete",
      "description" => "Onboarding process completed successfully",
      "resolution_type" => "success",
      "survey_trigger" => true,
      "transitions" => []
    }
  ]
)

# --- Template 4: Support Ticket Triage ---
st_welcome = SecureRandom.uuid
st_category = SecureRandom.uuid
st_priority = SecureRandom.uuid
st_customer = SecureRandom.uuid
st_emergency = SecureRandom.uuid
st_technical = SecureRandom.uuid
st_billing = SecureRandom.uuid
st_account = SecureRandom.uuid
st_escalation = SecureRandom.uuid
st_success = SecureRandom.uuid
st_product = SecureRandom.uuid
st_general = SecureRandom.uuid
st_routed = SecureRandom.uuid

Template.find_or_initialize_by(name: "Support Ticket Triage").update!(
  description: "A workflow for quickly categorizing, prioritizing, and routing incoming support tickets to the right team or resource. Improves response times and organization.",
  category: "customer-service",
  is_public: true,
  workflow_data: [
    {
      "id" => st_welcome,
      "type" => "message",
      "title" => "New Support Ticket",
      "description" => "Initial ticket intake",
      "content" => "**New Support Ticket Received**\n\nThis workflow will help you:\n1. Categorize the issue\n2. Determine priority level\n3. Route to appropriate team\n4. Set expectations for resolution\n\nGather: Ticket ID, customer contact info, issue description.",
      "transitions" => [{"target_uuid" => st_category}]
    },
    {
      "id" => st_category,
      "type" => "question",
      "title" => "Ticket Category",
      "description" => "Categorize the type of support request",
      "question" => "What category does this ticket fall into?",
      "answer_type" => "single_choice",
      "variable_name" => "ticket_category",
      "options" => [
        {"label" => "Technical Issue / Bug", "value" => "technical"},
        {"label" => "Billing / Payment", "value" => "billing"},
        {"label" => "Account Management", "value" => "account"},
        {"label" => "Feature Request", "value" => "feature"},
        {"label" => "General Question", "value" => "question"},
        {"label" => "Complaint / Escalation", "value" => "complaint"}
      ],
      "transitions" => [{"target_uuid" => st_priority}]
    },
    {
      "id" => st_priority,
      "type" => "question",
      "title" => "Priority Assessment",
      "description" => "Determine urgency level",
      "question" => "What is the priority level?",
      "answer_type" => "single_choice",
      "variable_name" => "priority",
      "options" => [
        {"label" => "Critical - System Down / Data Loss", "value" => "critical"},
        {"label" => "High - Major Feature Broken", "value" => "high"},
        {"label" => "Medium - Feature Issue / Workaround Available", "value" => "medium"},
        {"label" => "Low - Question / Enhancement Request", "value" => "low"}
      ],
      "transitions" => [{"target_uuid" => st_customer}]
    },
    {
      "id" => st_customer,
      "type" => "question",
      "title" => "Customer Type",
      "description" => "Identify customer segment for routing",
      "question" => "What type of customer is this?",
      "answer_type" => "single_choice",
      "variable_name" => "customer_type",
      "options" => [
        {"label" => "Enterprise / VIP Customer", "value" => "enterprise"},
        {"label" => "Regular Paid Customer", "value" => "paid"},
        {"label" => "Free/Trial Customer", "value" => "free"}
      ],
      "transitions" => [
        {"target_uuid" => st_emergency, "condition" => "ticket_category == 'technical' && priority == 'critical'", "label" => "Critical Technical"},
        {"target_uuid" => st_technical, "condition" => "ticket_category == 'technical'", "label" => "Technical"},
        {"target_uuid" => st_billing, "condition" => "ticket_category == 'billing'", "label" => "Billing"},
        {"target_uuid" => st_account, "condition" => "ticket_category == 'account'", "label" => "Account"},
        {"target_uuid" => st_escalation, "condition" => "ticket_category == 'complaint' && customer_type == 'enterprise'", "label" => "Enterprise Complaint"},
        {"target_uuid" => st_success, "condition" => "ticket_category == 'complaint'", "label" => "Complaint"},
        {"target_uuid" => st_product, "condition" => "ticket_category == 'feature'", "label" => "Feature Request"},
        {"target_uuid" => st_general, "label" => "General"}
      ]
    },
    {
      "id" => st_emergency,
      "type" => "escalate",
      "title" => "Route to Emergency Engineering",
      "description" => "Immediate escalation for critical technical issues",
      "target_type" => "team",
      "target_value" => "Emergency Engineering",
      "priority" => "critical",
      "reason_required" => true,
      "notes" => "CRITICAL: System down or data loss. Assign to on-call engineering team. SLA: 1-hour response time. Category: {{ticket_category}}, Priority: {{priority}}, Customer Type: {{customer_type}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_technical,
      "type" => "escalate",
      "title" => "Route to Technical Support",
      "description" => "Assign to technical support team",
      "target_type" => "queue",
      "target_value" => "Technical Support",
      "priority" => "high",
      "reason_required" => false,
      "notes" => "Set SLA based on priority: High: 4-hour, Medium: 24-hour, Low: 48-hour response. Category: {{ticket_category}}, Priority: {{priority}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_billing,
      "type" => "escalate",
      "title" => "Route to Billing Team",
      "description" => "Assign to billing/payments team",
      "target_type" => "department",
      "target_value" => "Billing",
      "priority" => "medium",
      "reason_required" => false,
      "notes" => "SLA: 24-hour response (same-day for urgent). Review billing history before responding. Priority: {{priority}}, Customer Type: {{customer_type}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_account,
      "type" => "escalate",
      "title" => "Route to Account Management",
      "description" => "Assign to account management team",
      "target_type" => "department",
      "target_value" => "Account Management",
      "priority" => "medium",
      "reason_required" => false,
      "notes" => "SLA: 24-hour response. For enterprise customers, assign to dedicated account manager. Customer Type: {{customer_type}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_escalation,
      "type" => "escalate",
      "title" => "Escalate - Enterprise Complaint",
      "description" => "Handle high-priority complaints from enterprise customers",
      "target_type" => "supervisor",
      "target_value" => "Senior Support / Escalation Team",
      "priority" => "urgent",
      "reason_required" => true,
      "notes" => "ENTERPRISE COMPLAINT: Notify account manager immediately. SLA: 2-hour response. Schedule follow-up call with customer. Customer Type: {{customer_type}}, Priority: {{priority}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_success,
      "type" => "escalate",
      "title" => "Route to Customer Success",
      "description" => "Assign complaints to customer success team",
      "target_type" => "team",
      "target_value" => "Customer Success",
      "priority" => "medium",
      "reason_required" => false,
      "notes" => "SLA: 24-hour response. Review customer history and sentiment. Prepare empathy-based response. Priority: {{priority}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_product,
      "type" => "action",
      "title" => "Log Feature Request",
      "description" => "Forward feature requests to product team",
      "action_type" => "instructions",
      "instructions" => "**Feature Request**\n\n**Steps:**\n1. Log in product roadmap tool\n2. Create feature request ticket\n3. Tag with relevant labels\n4. Send acknowledgment to customer (auto-respond)\n5. Link support ticket to product ticket\n\n**Note:** Feature requests are reviewed quarterly. Customer will be notified if selected for development.",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_general,
      "type" => "escalate",
      "title" => "Route to General Support",
      "description" => "Assign to general support queue",
      "target_type" => "queue",
      "target_value" => "General Support",
      "priority" => "low",
      "reason_required" => false,
      "notes" => "SLA: 24-48 hour response. Check knowledge base for standard responses. Category: {{ticket_category}}, Priority: {{priority}}",
      "transitions" => [{"target_uuid" => st_routed}]
    },
    {
      "id" => st_routed,
      "type" => "resolve",
      "title" => "Ticket Routed",
      "description" => "Support ticket has been categorized, prioritized, and routed to the appropriate team",
      "resolution_type" => "transferred",
      "notes_required" => false,
      "transitions" => []
    }
  ]
)

puts "Template library seeded successfully (Graph Mode)!"
puts "   - Email Troubleshooting"
puts "   - Refund Process"
puts "   - Customer Onboarding"
puts "   - Support Ticket Triage"
