# Seeds file for Kizuflow

# Create demo admin user for Render deployment
admin_user = User.find_or_initialize_by(email: "kevinkenney@corporatetools.com")
if admin_user.new_record?
  admin_user.password = "Password123!"
  admin_user.password_confirmation = "Password123!"
  admin_user.role = "admin"
  admin_user.save!
  puts "Created admin user: kevinkenney@corporatetools.com"
else
  # Update existing user to ensure they're an admin (only update role, not password)
  admin_user.update!(role: "admin")
  puts "Updated user to admin: kevinkenney@corporatetools.com"
end

# ============================================================================
# TEMPLATE LIBRARY - Pre-built workflow templates for common use cases
# ============================================================================
# These templates provide starting points for common business workflows.
# Users can duplicate these and customize them for their specific needs.
# ============================================================================

# Template 1: Email Troubleshooting (Simplified)
email_troubleshooting = Template.find_or_create_by!(name: "Email Troubleshooting") do |t|
  t.description = "A streamlined workflow for diagnosing and resolving email connectivity issues across common clients and devices. Perfect for customer support teams."
  t.category = "troubleshooting"
  t.is_public = true
  t.workflow_data = [
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Welcome - Email Troubleshooting",
      "description" => "Introduction to email troubleshooting workflow",
      "action_type" => "instructions",
      "instructions" => "This workflow will help diagnose and resolve email connectivity issues. Gather the following information:\n- Email address\n- Email client being used (Gmail, Outlook, Apple Mail)\n- Device type (Windows, Mac, iOS, Android)\n- Error messages (if any)"
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "decision",
      "title" => "Route to Solution",
      "description" => "Branch to appropriate troubleshooting path",
      "branches" => [
        {"condition" => "issue_type == 'auth_error'", "path" => "Fix Authentication Error"},
        {"condition" => "issue_type == 'timeout'", "path" => "Fix Connection Timeout"},
        {"condition" => "issue_type == 'certificate'", "path" => "Fix Certificate Error"},
        {"condition" => "issue_type == 'sync'", "path" => "Fix Sync Problems"}
      ],
      "else_path" => "General Troubleshooting"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Fix Authentication Error",
      "description" => "Steps to resolve authentication/password errors",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Incorrect password\n2. Wrong username format (use full email address)\n3. 2FA enabled without app password\n4. OAuth required (2026 update)\n\n**Solution Steps:**\n1. Verify password by logging into webmail\n2. Ensure username is the full email address (user@domain.com)\n3. If 2FA is enabled, generate an App Password from provider settings\n4. For Microsoft/Google: Try OAuth authentication if available"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Fix Connection Timeout",
      "description" => "Steps to resolve connection and server issues",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Incorrect server address\n2. Wrong port number\n3. Firewall blocking connection\n4. Network issues\n\n**Solution Steps:**\n1. Verify server addresses:\n   - IMAP: imap.domain.com or mail.domain.com\n   - SMTP: smtp.domain.com or mail.domain.com\n2. Verify ports:\n   - IMAP: 993 (SSL/TLS)\n   - SMTP: 465 (SSL) or 587 (STARTTLS)\n3. Check network connection and disable VPN if needed\n4. Try connecting from a different network"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Fix Certificate Error",
      "description" => "Steps to resolve SSL/TLS certificate issues",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Expired SSL certificate\n2. Incorrect device date/time\n3. Certificate hostname mismatch\n\n**Solution Steps:**\n1. **Check device date/time** - Ensure it's set correctly (this is the most common cause)\n2. Verify security settings match port:\n   - Port 993 requires SSL/TLS\n   - Port 587 requires STARTTLS\n3. Try alternate server address if available\n4. If certificate is genuinely expired, contact email provider"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Fix Sync Problems",
      "description" => "Steps to resolve email synchronization issues",
      "action_type" => "instructions",
      "instructions" => "**Common Causes:**\n1. Using POP instead of IMAP\n2. Sync settings too restrictive\n3. Storage quota exceeded\n\n**Solution Steps:**\n1. Verify using IMAP (not POP) for multi-device sync\n2. Check sync settings:\n   - iOS: Settings → Mail → Accounts → Mail Days to Sync\n   - Android: Gmail Settings → Days of mail to sync\n3. Check storage quota in webmail\n4. Remove and re-add account to clear local cache"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "General Troubleshooting",
      "description" => "General troubleshooting steps for other issues",
      "action_type" => "instructions",
      "instructions" => "**General Troubleshooting Steps:**\n1. Remove and re-add the email account\n2. Update email client to latest version\n3. Check provider's status page for outages\n4. Try a different email client temporarily\n5. Contact email provider support if issue persists"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Issue Resolved?",
      "description" => "Verify if the troubleshooting steps resolved the issue",
      "question" => "Was the issue resolved after following the troubleshooting steps?",
      "answer_type" => "yes_no",
      "variable_name" => "issue_resolved"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "decision",
      "title" => "Resolution Check",
      "description" => "Route based on resolution status",
      "branches" => [
        {"condition" => "issue_resolved == 'yes'", "path" => "Document Resolution"}
      ],
      "else_path" => "Escalate to Support"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Document Resolution",
      "description" => "Complete the troubleshooting session",
      "action_type" => "instructions",
      "instructions" => "**Troubleshooting Complete**\n\nPlease document:\n- Issue type: {issue_type}\n- Email client: {email_client}\n- Resolution steps taken\n- Any additional notes\n\nThank you for using this troubleshooting workflow!"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Escalate to Support",
      "description" => "Escalate unresolved issues to technical support",
      "action_type" => "instructions",
      "instructions" => "**Escalate to Technical Support**\n\nCollect the following information:\n1. Email client: {email_client}\n2. Issue type: {issue_type}\n3. Exact error messages (screenshot if possible)\n4. Steps already attempted\n5. Device/OS version\n\nContact your technical support team or email provider support with this information."
    }
  ]
end

# Template 2: Refund Process
refund_process = Template.find_or_create_by!(name: "Refund Process") do |t|
  t.description = "A systematic workflow for processing customer refunds with verification, approval, and documentation steps. Ensures consistent handling of refund requests."
  t.category = "customer-service"
  t.is_public = true
  t.workflow_data = [
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Refund Request Received",
      "description" => "Initial notification of refund request",
      "action_type" => "instructions",
      "instructions" => "**Refund Process Initiated**\n\nA customer has requested a refund. This workflow will guide you through:\n1. Verifying the purchase\n2. Checking refund eligibility\n3. Processing approval\n4. Initiating refund\n5. Notifying customer\n\nGather: Order number, customer email, purchase date, reason for refund."
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Order Verification",
      "description" => "Verify the order exists and is valid",
      "question" => "What is the order number or transaction ID?",
      "answer_type" => "text",
      "variable_name" => "order_number"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Purchase Date",
      "description" => "Determine when the purchase was made",
      "question" => "When was the purchase made? (or enter 'recent' if within last 30 days)",
      "answer_type" => "text",
      "variable_name" => "purchase_date"
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "decision",
      "title" => "Refund Eligibility",
      "description" => "Determine if refund is eligible based on policy",
      "branches" => [
        {"condition" => "refund_reason == 'defective'", "path" => "Approve Refund"},
        {"condition" => "refund_reason == 'not_as_described'", "path" => "Approve Refund"},
        {"condition" => "refund_reason == 'duplicate'", "path" => "Approve Refund"},
        {"condition" => "refund_reason == 'changed_mind'", "path" => "Check Return Window"}
      ],
      "else_path" => "Review Case"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Check Return Window",
      "description" => "Verify if purchase is within return window",
      "question" => "Is the purchase within the 30-day return window?",
      "answer_type" => "yes_no",
      "variable_name" => "within_window"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "decision",
      "title" => "Return Window Decision",
      "description" => "Route based on return window eligibility",
      "branches" => [
        {"condition" => "within_window == 'yes'", "path" => "Approve Refund"}
      ],
      "else_path" => "Deny Refund - Outside Window"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Approve Refund",
      "description" => "Process the approved refund",
      "action_type" => "instructions",
      "instructions" => "**Refund Approved**\n\nProceed with refund:\n1. Verify payment method (original payment source)\n2. Process refund through payment gateway\n3. Note refund amount (check original transaction)\n4. Record refund ID/confirmation number\n5. Document: Order {order_number}, Reason: {refund_reason}\n\nRefund typically processes within 5-10 business days."
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Process Refund Payment",
      "description" => "Execute the refund transaction",
      "action_type" => "instructions",
      "instructions" => "**Processing Refund**\n\n1. Log into payment gateway\n2. Locate transaction: {order_number}\n3. Initiate refund (full or partial as applicable)\n4. Copy refund confirmation/transaction ID\n5. Update order status to 'Refunded' in system"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Notify Customer",
      "description" => "Send confirmation email to customer",
      "action_type" => "instructions",
      "instructions" => "**Customer Notification**\n\nSend email to customer:\n\nSubject: Refund Processed - Order {order_number}\n\nBody:\n- Confirm refund has been processed\n- Refund amount and method\n- Expected processing time (5-10 business days)\n- Refund confirmation ID\n- Thank customer for their patience"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Deny Refund - Outside Window",
      "description" => "Handle refund denial for purchases outside return window",
      "action_type" => "instructions",
      "instructions" => "**Refund Denied - Outside Return Window**\n\nPurchase date: {purchase_date}\n\nSend polite denial email:\n- Explain return policy (30-day window)\n- Offer alternative: Store credit or exchange (if applicable)\n- Apologize for any inconvenience\n- Provide contact for further questions"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Review Case",
      "description" => "Manual review required for special cases",
      "action_type" => "instructions",
      "instructions" => "**Manual Review Required**\n\nReason: {refund_reason}\nOrder: {order_number}\n\nEscalate to supervisor for review:\n1. Document all case details\n2. Include customer communication history\n3. Flag for supervisor approval\n4. Follow up within 24-48 hours"
    }
  ]
end

# Template 3: Customer Onboarding
customer_onboarding = Template.find_or_create_by!(name: "Customer Onboarding") do |t|
  t.description = "A comprehensive onboarding workflow to welcome new customers, collect preferences, provide initial setup guidance, and ensure a smooth first experience."
  t.category = "onboarding"
  t.is_public = true
  t.workflow_data = [
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Welcome New Customer",
      "description" => "Initial welcome message for new customer",
      "action_type" => "instructions",
      "instructions" => "**Welcome!**\n\nThank you for choosing our service. This onboarding process will help you:\n1. Set up your account\n2. Configure preferences\n3. Learn key features\n4. Get started with best practices\n\nThis should take about 10-15 minutes."
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Customer Name",
      "description" => "Collect customer's name for personalization",
      "question" => "What is your full name?",
      "answer_type" => "text",
      "variable_name" => "customer_name"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Company Information",
      "description" => "Optional company details",
      "question" => "What company or organization are you with? (Optional)",
      "answer_type" => "text",
      "variable_name" => "company_name"
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "decision",
      "title" => "Route by Experience Level",
      "description" => "Customize onboarding path based on experience",
      "branches" => [
        {"condition" => "experience_level == 'beginner'", "path" => "Beginner Setup Guide"},
        {"condition" => "experience_level == 'intermediate'", "path" => "Intermediate Setup Guide"},
        {"condition" => "experience_level == 'advanced'", "path" => "Advanced Quick Start"}
      ],
      "else_path" => "Beginner Setup Guide"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Beginner Setup Guide",
      "description" => "Detailed setup instructions for beginners",
      "action_type" => "instructions",
      "instructions" => "**Welcome, {customer_name}!**\n\nLet's get you started step-by-step:\n\n**Step 1: Account Verification**\n- Check your email for verification link\n- Click the link to activate your account\n\n**Step 2: Profile Setup**\n- Complete your profile information\n- Upload a profile picture (optional)\n- Set your timezone\n\n**Step 3: Explore Dashboard**\n- Familiarize yourself with the main dashboard\n- Review the navigation menu\n- Check out the help documentation\n\nTake your time - there's no rush!"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Intermediate Setup Guide",
      "description" => "Streamlined setup for users with some experience",
      "action_type" => "instructions",
      "instructions" => "**Hello, {customer_name}!**\n\nHere's your quick start guide:\n\n**Essential Setup:**\n1. Verify your email address\n2. Complete basic profile information\n3. Review key features in the dashboard\n4. Check out the tutorial videos (optional)\n\n**Recommended Next Steps:**\n- Explore advanced settings\n- Review integration options\n- Set up your first project/workflow\n\nNeed help? Our support team is available!"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Advanced Quick Start",
      "description" => "Minimal setup for experienced users",
      "action_type" => "instructions",
      "instructions" => "**Welcome, {customer_name}!**\n\nQuick start for experienced users:\n\n**Essential Only:**\n1. Verify email\n2. Review API documentation (if applicable)\n3. Configure integrations\n\n**Resources:**\n- API docs: /docs/api\n- Advanced features: /features\n- Community forum: /community\n\nYou're all set! Dive right in."
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Setup Complete",
      "description" => "Verify user completed initial setup",
      "question" => "Have you completed the initial account setup? (Email verified, profile created)",
      "answer_type" => "yes_no",
      "variable_name" => "setup_complete"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Onboarding Complete",
      "description" => "Final welcome and next steps",
      "action_type" => "instructions",
      "instructions" => "**🎉 Onboarding Complete!**\n\nWelcome to the team, {customer_name}!\n\n**What's Next:**\n1. Explore key features\n2. Check out example workflows/templates\n3. Join our community forum\n4. Contact support if you have questions\n\n**Resources:**\n- Help Center: /help\n- Video Tutorials: /tutorials\n- Best Practices Guide: /guides\n\nWe're here to help you succeed!"
    }
  ]
end

# Template 4: Support Ticket Triage
support_triage = Template.find_or_create_by!(name: "Support Ticket Triage") do |t|
  t.description = "A workflow for quickly categorizing, prioritizing, and routing incoming support tickets to the right team or resource. Improves response times and organization."
  t.category = "customer-service"
  t.is_public = true
  t.workflow_data = [
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "New Support Ticket",
      "description" => "Initial ticket intake",
      "action_type" => "instructions",
      "instructions" => "**New Support Ticket Received**\n\nThis workflow will help you:\n1. Categorize the issue\n2. Determine priority level\n3. Route to appropriate team\n4. Set expectations for resolution\n\nGather: Ticket ID, customer contact info, issue description."
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
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
      ]
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "question",
      "title" => "Customer Type",
      "description" => "Identify customer segment",
      "question" => "What type of customer is this?",
      "answer_type" => "single_choice",
      "variable_name" => "customer_type",
      "options" => [
        {"label" => "Enterprise / VIP Customer", "value" => "enterprise"},
        {"label" => "Regular Paid Customer", "value" => "paid"},
        {"label" => "Free/Trial Customer", "value" => "free"}
      ]
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "decision",
      "title" => "Route Ticket",
      "description" => "Route to appropriate team based on category and priority",
      "branches" => [
        {"condition" => "ticket_category == 'technical' && priority == 'critical'", "path" => "Route to Emergency Engineering"},
        {"condition" => "ticket_category == 'technical'", "path" => "Route to Technical Support"},
        {"condition" => "ticket_category == 'billing'", "path" => "Route to Billing Team"},
        {"condition" => "ticket_category == 'account'", "path" => "Route to Account Management"},
        {"condition" => "ticket_category == 'complaint' && customer_type == 'enterprise'", "path" => "Route to Escalation Team"},
        {"condition" => "ticket_category == 'complaint'", "path" => "Route to Customer Success"},
        {"condition" => "ticket_category == 'feature'", "path" => "Route to Product Team"},
        {"condition" => "ticket_category == 'question'", "path" => "Route to General Support"}
      ],
      "else_path" => "Route to General Support"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Emergency Engineering",
      "description" => "Immediate escalation for critical technical issues",
      "action_type" => "instructions",
      "instructions" => "**🚨 CRITICAL TICKET - Emergency Engineering**\n\n**Action Required Immediately:**\n1. Assign to on-call engineering team\n2. Send urgent notification to engineering manager\n3. Create incident ticket\n4. Set SLA: 1-hour response time\n5. Notify customer of escalation and expected response time\n\n**Details:**\n- Category: {ticket_category}\n- Priority: {priority}\n- Customer Type: {customer_type}"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Technical Support",
      "description" => "Assign to technical support team",
      "action_type" => "instructions",
      "instructions" => "**Technical Support Ticket**\n\n**Assignment:**\n1. Assign to technical support queue\n2. Set SLA based on priority:\n   - High: 4-hour response\n   - Medium: 24-hour response\n   - Low: 48-hour response\n3. Tag with relevant technical tags\n4. Include ticket details in assignment\n\n**Category:** {ticket_category}\n**Priority:** {priority}"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Billing Team",
      "description" => "Assign to billing/payments team",
      "action_type" => "instructions",
      "instructions" => "**Billing Ticket**\n\n**Assignment:**\n1. Assign to billing team\n2. Set SLA: 24-hour response (same-day for urgent)\n3. Review billing history before responding\n4. Ensure compliance with refund/cancellation policies\n\n**Priority:** {priority}\n**Customer Type:** {customer_type}"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Account Management",
      "description" => "Assign to account management team",
      "action_type" => "instructions",
      "instructions" => "**Account Management Ticket**\n\n**Assignment:**\n1. Assign to account management queue\n2. Set SLA: 24-hour response\n3. Review account details and history\n4. For enterprise customers, assign to dedicated account manager\n\n**Customer Type:** {customer_type}"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Escalation Team",
      "description" => "Handle high-priority complaints from enterprise customers",
      "action_type" => "instructions",
      "instructions" => "**⚠️ ESCALATION - Enterprise Complaint**\n\n**Immediate Action:**\n1. Assign to escalation/senior support team\n2. Notify account manager\n3. Set SLA: 2-hour response time\n4. Prepare executive summary if needed\n5. Schedule follow-up call with customer\n\n**Customer Type:** {customer_type}\n**Priority:** {priority}"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Customer Success",
      "description" => "Assign to customer success for complaints",
      "action_type" => "instructions",
      "instructions" => "**Customer Success - Complaint Handling**\n\n**Assignment:**\n1. Assign to customer success team\n2. Set SLA: 24-hour response\n3. Review customer history and sentiment\n4. Prepare empathy-based response\n5. Offer appropriate resolution\n\n**Priority:** {priority}"
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to Product Team",
      "description" => "Forward feature requests to product team",
      "action_type" => "instructions",
      "instructions" => "**Feature Request**\n\n**Assignment:**\n1. Log in product roadmap tool\n2. Create feature request ticket\n3. Tag with relevant labels\n4. Acknowledge to customer (auto-respond)\n5. Link support ticket to product ticket\n\n**Note:** Feature requests are reviewed quarterly. Customer will be notified if selected."
    },
    {
      "id" => SecureRandom.uuid,
      "type" => "action",
      "title" => "Route to General Support",
      "description" => "Assign to general support queue",
      "action_type" => "instructions",
      "instructions" => "**General Support Ticket**\n\n**Assignment:**\n1. Assign to general support queue\n2. Set SLA: 24-48 hour response\n3. Check knowledge base for standard responses\n4. Use FAQ resources when applicable\n\n**Category:** {ticket_category}\n**Priority:** {priority}"
    }
  ]
end

puts "✅ Template library seeded successfully!"
puts "   - Email Troubleshooting"
puts "   - Refund Process"
puts "   - Customer Onboarding"
puts "   - Support Ticket Triage"
