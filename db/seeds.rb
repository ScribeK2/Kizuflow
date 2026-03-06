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
# TEMPLATE LIBRARY - Call/Chat Center Workflow Templates (Graph Mode)
# ============================================================================
# These templates provide starting points for common call/chat center workflows.
# All templates use graph mode with explicit transitions between steps.
# Step types: question, action, message, escalate, resolve
# Categories: troubleshooting, account-management, complaints-retention, sales-onboarding
# ============================================================================

# --- Template 1: Internet Connectivity Troubleshooting ---
ic_welcome = SecureRandom.uuid
ic_issue_type = SecureRandom.uuid
ic_no_connection = SecureRandom.uuid
ic_slow_speeds = SecureRandom.uuid
ic_intermittent = SecureRandom.uuid
ic_general = SecureRandom.uuid
ic_basic_resolved = SecureRandom.uuid
ic_advanced = SecureRandom.uuid
ic_advanced_resolved = SecureRandom.uuid
ic_resolved = SecureRandom.uuid
ic_escalate = SecureRandom.uuid
ic_escalate_resolve = SecureRandom.uuid

Template.find_or_initialize_by(name: "Internet Connectivity Troubleshooting").update!(
  description: "A structured workflow for diagnosing and resolving internet connectivity issues. Covers no connection, slow speeds, and intermittent problems with escalation paths.",
  category: "troubleshooting",
  is_public: true,
  graph_mode: true,
  start_node_uuid: ic_welcome,
  workflow_data: [
    {
      "id" => ic_welcome,
      "type" => "message",
      "title" => "Internet Connectivity Troubleshooting",
      "content" => "Welcome to Internet Connectivity Troubleshooting.\n\nGather the following information from the customer:\n- Account number\n- Device type (computer, phone, tablet, smart TV)\n- Connection type (WiFi or Ethernet)\n- Modem/router make and model (if known)",
      "transitions" => [{"target_uuid" => ic_issue_type}]
    },
    {
      "id" => ic_issue_type,
      "type" => "question",
      "title" => "What type of connectivity issue?",
      "question" => "What type of connectivity issue is the customer experiencing?",
      "answer_type" => "single_choice",
      "variable_name" => "issue_type",
      "options" => [
        {"label" => "No connection at all", "value" => "no_connection"},
        {"label" => "Slow speeds", "value" => "slow_speeds"},
        {"label" => "Intermittent / drops in and out", "value" => "intermittent"},
        {"label" => "Other connectivity issue", "value" => "other"}
      ],
      "transitions" => [
        {"target_uuid" => ic_no_connection, "condition" => "issue_type == 'no_connection'", "label" => "No Connection"},
        {"target_uuid" => ic_slow_speeds, "condition" => "issue_type == 'slow_speeds'", "label" => "Slow Speeds"},
        {"target_uuid" => ic_intermittent, "condition" => "issue_type == 'intermittent'", "label" => "Intermittent"},
        {"target_uuid" => ic_general, "label" => "Other"}
      ]
    },
    {
      "id" => ic_no_connection,
      "type" => "action",
      "title" => "No Connection: Basic Checks",
      "action_type" => "instructions",
      "instructions" => "**No Connection Troubleshooting:**\n\n1. **Restart modem/router** — Unplug power for 30 seconds, plug back in, wait 2-3 minutes\n2. **Check cable connections** — Ensure coax/fiber cable is securely connected to modem\n3. **Check modem lights** — Power (solid), Online (solid), WiFi (blinking = normal)\n4. **Try direct Ethernet connection** — Bypass WiFi to isolate the issue\n5. **Check for service outage** — Look up area status on provider's outage map",
      "transitions" => [{"target_uuid" => ic_basic_resolved}]
    },
    {
      "id" => ic_slow_speeds,
      "type" => "action",
      "title" => "Slow Speeds: Diagnosis",
      "action_type" => "instructions",
      "instructions" => "**Slow Speed Troubleshooting:**\n\n1. **Run a speed test** — Use speedtest.net or fast.com, compare to plan speeds\n2. **Check connected devices** — Too many devices can saturate bandwidth\n3. **Check for WiFi interference** — Move router away from microwaves, baby monitors, thick walls\n4. **Test with Ethernet** — If Ethernet is fast but WiFi is slow, it's a WiFi issue\n5. **Check for background downloads** — Updates, cloud backups, streaming on other devices",
      "transitions" => [{"target_uuid" => ic_basic_resolved}]
    },
    {
      "id" => ic_intermittent,
      "type" => "action",
      "title" => "Intermittent Connection: Diagnosis",
      "action_type" => "instructions",
      "instructions" => "**Intermittent Connection Troubleshooting:**\n\n1. **Check WiFi signal strength** — Move closer to router or check signal bars\n2. **Check for firmware updates** — Log into router admin page, check for updates\n3. **Test with Ethernet cable** — If stable on Ethernet, the issue is WiFi-related\n4. **Check for pattern** — Does it drop at certain times? Could be network congestion\n5. **Check cables for damage** — Frayed or bent cables can cause intermittent issues",
      "transitions" => [{"target_uuid" => ic_basic_resolved}]
    },
    {
      "id" => ic_general,
      "type" => "action",
      "title" => "General Troubleshooting",
      "action_type" => "instructions",
      "instructions" => "**General Connectivity Troubleshooting:**\n\n1. **Check provider status page** — Look for known outages in the area\n2. **Try a different device** — Isolate whether the issue is device-specific\n3. **Reset network settings** — On the affected device, forget and reconnect to WiFi\n4. **Restart the affected device** — A simple reboot often resolves connectivity issues\n5. **Check date/time settings** — Incorrect time can cause certificate/auth failures",
      "transitions" => [{"target_uuid" => ic_basic_resolved}]
    },
    {
      "id" => ic_basic_resolved,
      "type" => "question",
      "title" => "Did the basic troubleshooting resolve the issue?",
      "question" => "Did the basic troubleshooting steps resolve the customer's connectivity issue?",
      "answer_type" => "yes_no",
      "variable_name" => "basic_resolved",
      "transitions" => [
        {"target_uuid" => ic_resolved, "condition" => "basic_resolved == 'yes'", "label" => "Resolved"},
        {"target_uuid" => ic_advanced, "condition" => "basic_resolved == 'no'", "label" => "Not Resolved"}
      ]
    },
    {
      "id" => ic_advanced,
      "type" => "action",
      "title" => "Advanced Troubleshooting",
      "action_type" => "instructions",
      "instructions" => "**Advanced Troubleshooting Steps:**\n\n1. **Check DNS settings** — Try switching to Google DNS (8.8.8.8) or Cloudflare (1.1.1.1)\n2. **Flush DNS cache** — Windows: ipconfig /flushdns | Mac: sudo dscacheutil -flushcache\n3. **Check for IP conflicts** — Release and renew IP: ipconfig /release then /renew\n4. **Disable VPN** — VPNs can interfere with local network connectivity\n5. **Factory reset router** — Last resort, will need to reconfigure WiFi name/password\n6. **Check signal levels** — Log into modem admin page, check downstream/upstream levels",
      "transitions" => [{"target_uuid" => ic_advanced_resolved}]
    },
    {
      "id" => ic_advanced_resolved,
      "type" => "question",
      "title" => "Is the issue resolved after advanced troubleshooting?",
      "question" => "Is the customer's connectivity issue resolved after advanced troubleshooting?",
      "answer_type" => "yes_no",
      "variable_name" => "advanced_resolved",
      "transitions" => [
        {"target_uuid" => ic_resolved, "condition" => "advanced_resolved == 'yes'", "label" => "Resolved"},
        {"target_uuid" => ic_escalate, "condition" => "advanced_resolved == 'no'", "label" => "Not Resolved"}
      ]
    },
    {
      "id" => ic_resolved,
      "type" => "resolve",
      "title" => "Issue Resolved",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => ic_escalate,
      "type" => "escalate",
      "title" => "Escalate to Network Engineering",
      "target_type" => "department",
      "target_value" => "Network Engineering",
      "priority" => "high",
      "reason_required" => true,
      "notes" => "Issue type: {{issue_type}}. Basic and advanced troubleshooting completed without resolution. Include modem signal levels and any error codes observed.",
      "transitions" => [{"target_uuid" => ic_escalate_resolve}]
    },
    {
      "id" => ic_escalate_resolve,
      "type" => "resolve",
      "title" => "Escalation Complete",
      "resolution_type" => "escalated",
      "transitions" => []
    }
  ]
)

# --- Template 2: Email Setup & Configuration ---
es_welcome = SecureRandom.uuid
es_client = SecureRandom.uuid
es_issue = SecureRandom.uuid
es_new_setup = SecureRandom.uuid
es_auth_error = SecureRandom.uuid
es_sync_issues = SecureRandom.uuid
es_sending_failed = SecureRandom.uuid
es_general = SecureRandom.uuid
es_resolved_q = SecureRandom.uuid
es_resolved = SecureRandom.uuid
es_escalate = SecureRandom.uuid

Template.find_or_initialize_by(name: "Email Setup & Configuration").update!(
  description: "Guide agents through email client setup, authentication errors, sync issues, and sending failures across all major email clients.",
  category: "troubleshooting",
  is_public: true,
  graph_mode: true,
  start_node_uuid: es_welcome,
  workflow_data: [
    {
      "id" => es_welcome,
      "type" => "message",
      "title" => "Email Setup & Configuration",
      "content" => "Welcome to Email Setup & Configuration support.\n\nGather the following information:\n- Customer's email address\n- Email client (Gmail, Outlook, Apple Mail, Thunderbird, other)\n- Device type and OS version\n- Any error messages displayed",
      "transitions" => [{"target_uuid" => es_client}]
    },
    {
      "id" => es_client,
      "type" => "question",
      "title" => "Which email client?",
      "question" => "Which email client is the customer using?",
      "answer_type" => "single_choice",
      "variable_name" => "email_client",
      "options" => [
        {"label" => "Gmail (App or Web)", "value" => "gmail"},
        {"label" => "Microsoft Outlook", "value" => "outlook"},
        {"label" => "Apple Mail", "value" => "apple_mail"},
        {"label" => "Thunderbird", "value" => "thunderbird"},
        {"label" => "Other", "value" => "other"}
      ],
      "transitions" => [{"target_uuid" => es_issue}]
    },
    {
      "id" => es_issue,
      "type" => "question",
      "title" => "What is the issue?",
      "question" => "What email issue is the customer experiencing?",
      "answer_type" => "single_choice",
      "variable_name" => "email_issue",
      "options" => [
        {"label" => "New email account setup", "value" => "new_setup"},
        {"label" => "Authentication error / can't sign in", "value" => "auth_error"},
        {"label" => "Sync issues / missing emails", "value" => "sync_issues"},
        {"label" => "Can't send emails", "value" => "sending_failed"},
        {"label" => "Other", "value" => "other"}
      ],
      "transitions" => [
        {"target_uuid" => es_new_setup, "condition" => "email_issue == 'new_setup'", "label" => "New Setup"},
        {"target_uuid" => es_auth_error, "condition" => "email_issue == 'auth_error'", "label" => "Auth Error"},
        {"target_uuid" => es_sync_issues, "condition" => "email_issue == 'sync_issues'", "label" => "Sync Issues"},
        {"target_uuid" => es_sending_failed, "condition" => "email_issue == 'sending_failed'", "label" => "Sending Failed"},
        {"target_uuid" => es_general, "label" => "Other"}
      ]
    },
    {
      "id" => es_new_setup,
      "type" => "action",
      "title" => "New Email Setup",
      "action_type" => "instructions",
      "instructions" => "**New Email Account Setup:**\n\n1. **IMAP Settings (Incoming):**\n   - Server: imap.provider.com\n   - Port: 993\n   - Security: SSL/TLS\n\n2. **SMTP Settings (Outgoing):**\n   - Server: smtp.provider.com\n   - Port: 465 (SSL) or 587 (STARTTLS)\n   - Security: SSL/TLS or STARTTLS\n\n3. **Authentication:**\n   - Username: full email address\n   - Password: account password (or app password if 2FA enabled)\n   - Auth method: OAuth2 (preferred for Gmail/Outlook)\n\n4. Walk customer through Add Account wizard in their email client",
      "transitions" => [{"target_uuid" => es_resolved_q}]
    },
    {
      "id" => es_auth_error,
      "type" => "action",
      "title" => "Fix Authentication Error",
      "action_type" => "instructions",
      "instructions" => "**Authentication Error Resolution:**\n\n1. **Verify credentials** — Have customer log in via webmail to confirm password works\n2. **Check for 2FA** — If enabled, generate an app-specific password from provider settings\n3. **Try OAuth** — For Gmail/Outlook, remove account and re-add using OAuth sign-in\n4. **Check account status** — Ensure account isn't locked or suspended\n5. **Clear saved passwords** — Remove old credentials from system keychain/credential manager",
      "transitions" => [{"target_uuid" => es_resolved_q}]
    },
    {
      "id" => es_sync_issues,
      "type" => "action",
      "title" => "Fix Sync Issues",
      "action_type" => "instructions",
      "instructions" => "**Sync Issue Resolution:**\n\n1. **Verify IMAP (not POP)** — POP downloads and removes from server; IMAP syncs\n2. **Check sync period** — Increase 'Mail Days to Sync' setting (some default to 1 month)\n3. **Check storage quota** — Full mailbox can prevent sync; archive or delete old emails\n4. **Re-add account** — Remove and re-add the email account to force a fresh sync\n5. **Check folder subscriptions** — In IMAP settings, ensure all folders are subscribed",
      "transitions" => [{"target_uuid" => es_resolved_q}]
    },
    {
      "id" => es_sending_failed,
      "type" => "action",
      "title" => "Fix Sending Failed",
      "action_type" => "instructions",
      "instructions" => "**Sending Failed Resolution:**\n\n1. **Verify SMTP settings** — Server, port (465 or 587), and security type\n2. **Check attachment size** — Most providers limit to 25MB; suggest cloud link for large files\n3. **Verify sender address** — Must match the authenticated account\n4. **Check outgoing authentication** — SMTP requires authentication; ensure it's enabled\n5. **Test with simple email** — Send a plain text email with no attachments to yourself",
      "transitions" => [{"target_uuid" => es_resolved_q}]
    },
    {
      "id" => es_general,
      "type" => "action",
      "title" => "General Email Troubleshooting",
      "action_type" => "instructions",
      "instructions" => "**General Email Troubleshooting:**\n\n1. **Update email client** — Ensure the latest version is installed\n2. **Check provider status** — Visit provider's status page for outages\n3. **Try webmail** — If webmail works but client doesn't, the issue is client-side\n4. **Restart device** — Clears temporary network/app issues\n5. **Check internet connection** — Verify general internet access works",
      "transitions" => [{"target_uuid" => es_resolved_q}]
    },
    {
      "id" => es_resolved_q,
      "type" => "question",
      "title" => "Is the email issue resolved?",
      "question" => "Has the customer's email issue been resolved?",
      "answer_type" => "yes_no",
      "variable_name" => "email_resolved",
      "transitions" => [
        {"target_uuid" => es_resolved, "condition" => "email_resolved == 'yes'", "label" => "Resolved"},
        {"target_uuid" => es_escalate, "condition" => "email_resolved == 'no'", "label" => "Not Resolved"}
      ]
    },
    {
      "id" => es_resolved,
      "type" => "resolve",
      "title" => "Issue Resolved",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => es_escalate,
      "type" => "escalate",
      "title" => "Escalate to Email Support",
      "target_type" => "department",
      "target_value" => "Email & Messaging Support",
      "priority" => "high",
      "reason_required" => true,
      "notes" => "Email client: {{email_client}}, Issue: {{email_issue}}. Basic troubleshooting completed. Include exact error messages and steps attempted.",
      "transitions" => []
    }
  ]
)

# --- Template 3: Account Verification & Security ---
av_welcome = SecureRandom.uuid
av_account_id = SecureRandom.uuid
av_method = SecureRandom.uuid
av_perform = SecureRandom.uuid
av_passed = SecureRandom.uuid
av_success_msg = SecureRandom.uuid
av_success_resolve = SecureRandom.uuid
av_failed_msg = SecureRandom.uuid
av_escalate = SecureRandom.uuid

Template.find_or_initialize_by(name: "Account Verification & Security").update!(
  description: "Verify customer identity before processing sensitive account changes. Supports security questions, SMS/email codes, and ID document verification.",
  category: "account-management",
  is_public: true,
  graph_mode: true,
  start_node_uuid: av_welcome,
  workflow_data: [
    {
      "id" => av_welcome,
      "type" => "message",
      "title" => "Account Verification Required",
      "content" => "**Identity Verification Required**\n\nBefore making any account changes, we must verify the customer's identity.\n\nExplain to the customer:\n- This is a standard security procedure\n- It protects their account from unauthorized changes\n- It should only take a moment",
      "transitions" => [{"target_uuid" => av_account_id}]
    },
    {
      "id" => av_account_id,
      "type" => "question",
      "title" => "Customer account number or email?",
      "question" => "What is the customer's account number or email address?",
      "answer_type" => "text",
      "variable_name" => "account_identifier",
      "transitions" => [{"target_uuid" => av_method}]
    },
    {
      "id" => av_method,
      "type" => "question",
      "title" => "Verification method",
      "question" => "Which verification method will be used?",
      "answer_type" => "single_choice",
      "variable_name" => "verification_method",
      "options" => [
        {"label" => "Security questions", "value" => "security_questions"},
        {"label" => "SMS verification code", "value" => "sms_code"},
        {"label" => "Email verification code", "value" => "email_code"},
        {"label" => "ID document upload", "value" => "id_document"}
      ],
      "transitions" => [{"target_uuid" => av_perform}]
    },
    {
      "id" => av_perform,
      "type" => "action",
      "title" => "Perform Identity Verification",
      "action_type" => "instructions",
      "instructions" => "**Follow the selected verification method:**\n\n**Security Questions:** Ask the pre-set security questions and compare answers.\n\n**SMS Code:** Send verification code to the phone number on file. Ask customer to read back the code.\n\n**Email Code:** Send verification code to the email on file. Ask customer to read back the code.\n\n**ID Document:** Request customer uploads a government-issued photo ID. Verify name and DOB match account records.\n\n**Important:** Do not reveal which answers are correct/incorrect during verification.",
      "transitions" => [{"target_uuid" => av_passed}]
    },
    {
      "id" => av_passed,
      "type" => "question",
      "title" => "Did the customer pass identity verification?",
      "question" => "Did the customer successfully pass identity verification?",
      "answer_type" => "yes_no",
      "variable_name" => "verified",
      "transitions" => [
        {"target_uuid" => av_success_msg, "condition" => "verified == 'yes'", "label" => "Verified"},
        {"target_uuid" => av_failed_msg, "condition" => "verified == 'no'", "label" => "Failed"}
      ]
    },
    {
      "id" => av_success_msg,
      "type" => "message",
      "title" => "Verification Successful",
      "content" => "**Identity Confirmed**\n\nThe customer's identity has been verified for account {{account_identifier}}.\n\nYou may now proceed with the requested account changes.\n\nDocument this verification in the account notes.",
      "transitions" => [{"target_uuid" => av_success_resolve}]
    },
    {
      "id" => av_success_resolve,
      "type" => "resolve",
      "title" => "Verification Complete",
      "resolution_type" => "success",
      "transitions" => []
    },
    {
      "id" => av_failed_msg,
      "type" => "message",
      "title" => "Verification Failed",
      "content" => "**Verification Failed**\n\nThe customer did not pass identity verification.\n\n1. Inform the customer that verification was unsuccessful\n2. Offer to try an alternative verification method\n3. If this is the 3rd failed attempt, lock the account for security\n4. Do NOT proceed with any account changes\n\nAccount: {{account_identifier}}, Method attempted: {{verification_method}}",
      "transitions" => [{"target_uuid" => av_escalate}]
    },
    {
      "id" => av_escalate,
      "type" => "escalate",
      "title" => "Escalate Failed Verification",
      "target_type" => "supervisor",
      "target_value" => "Account Security Team",
      "priority" => "high",
      "reason_required" => true,
      "notes" => "Failed identity verification. Account: {{account_identifier}}, Method: {{verification_method}}. Review for potential unauthorized access attempt.",
      "transitions" => []
    }
  ]
)

# --- Template 4: Password Reset & Account Recovery ---
pr_welcome = SecureRandom.uuid
pr_recovery_type = SecureRandom.uuid
pr_password_reset = SecureRandom.uuid
pr_2fa_recovery = SecureRandom.uuid
pr_unlock = SecureRandom.uuid
pr_username_recovery = SecureRandom.uuid
pr_access_q = SecureRandom.uuid
pr_security_check = SecureRandom.uuid
pr_resolved = SecureRandom.uuid
pr_escalate = SecureRandom.uuid

Template.find_or_initialize_by(name: "Password Reset & Account Recovery").update!(
  description: "Help customers reset passwords, recover 2FA access, unlock accounts, and recover usernames with post-recovery security checks.",
  category: "account-management",
  is_public: true,
  graph_mode: true,
  start_node_uuid: pr_welcome,
  workflow_data: [
    {
      "id" => pr_welcome,
      "type" => "message",
      "title" => "Password Reset & Account Recovery",
      "content" => "Welcome to Password Reset & Account Recovery.\n\nGather the following information:\n- Customer's account email address\n- What they are trying to do (reset password, recover 2FA, unlock account, recover username)\n- Any error messages they are seeing",
      "transitions" => [{"target_uuid" => pr_recovery_type}]
    },
    {
      "id" => pr_recovery_type,
      "type" => "question",
      "title" => "What does the customer need help with?",
      "question" => "What type of account recovery does the customer need?",
      "answer_type" => "single_choice",
      "variable_name" => "recovery_type",
      "options" => [
        {"label" => "Password reset", "value" => "password_reset"},
        {"label" => "Two-factor authentication recovery", "value" => "two_factor_recovery"},
        {"label" => "Locked account", "value" => "locked_account"},
        {"label" => "Username / email recovery", "value" => "username_recovery"}
      ],
      "transitions" => [
        {"target_uuid" => pr_password_reset, "condition" => "recovery_type == 'password_reset'", "label" => "Password Reset"},
        {"target_uuid" => pr_2fa_recovery, "condition" => "recovery_type == 'two_factor_recovery'", "label" => "2FA Recovery"},
        {"target_uuid" => pr_unlock, "condition" => "recovery_type == 'locked_account'", "label" => "Locked Account"},
        {"target_uuid" => pr_username_recovery, "condition" => "recovery_type == 'username_recovery'", "label" => "Username Recovery"}
      ]
    },
    {
      "id" => pr_password_reset,
      "type" => "action",
      "title" => "Password Reset Process",
      "action_type" => "instructions",
      "instructions" => "**Password Reset Steps:**\n\n1. **Send reset link** — Trigger password reset email to the account's email address\n2. **Walk through reset** — Guide customer to check email (including spam), click the reset link\n3. **Set new password** — Ensure they choose a strong password (12+ chars, mixed case, numbers, symbols)\n4. **Verify new password** — Have customer log in with the new password to confirm\n5. **Update records** — Note the password reset in account history",
      "transitions" => [{"target_uuid" => pr_access_q}]
    },
    {
      "id" => pr_2fa_recovery,
      "type" => "action",
      "title" => "2FA Recovery Process",
      "action_type" => "instructions",
      "instructions" => "**2FA Recovery Steps:**\n\n1. **Verify identity** — Use alternate verification method (security questions, ID document)\n2. **Disable old 2FA** — Remove the existing 2FA method from the account\n3. **Set up new 2FA** — Walk customer through setting up a new authenticator app or SMS\n4. **Provide backup codes** — Generate and share new backup/recovery codes\n5. **Test 2FA** — Have customer log out and log back in to verify new 2FA works",
      "transitions" => [{"target_uuid" => pr_access_q}]
    },
    {
      "id" => pr_unlock,
      "type" => "action",
      "title" => "Unlock Account Process",
      "action_type" => "instructions",
      "instructions" => "**Account Unlock Steps:**\n\n1. **Verify identity** — Confirm the customer is the account owner\n2. **Review lock reason** — Check account logs for why it was locked (failed attempts, suspicious activity, admin lock)\n3. **Clear failed attempts** — Reset the login attempt counter\n4. **Unlock account** — Remove the lock from the account\n5. **Security advisory** — If locked due to suspicious activity, recommend password change and 2FA setup",
      "transitions" => [{"target_uuid" => pr_access_q}]
    },
    {
      "id" => pr_username_recovery,
      "type" => "action",
      "title" => "Username Recovery",
      "action_type" => "instructions",
      "instructions" => "**Username Recovery Steps:**\n\n1. **Verify identity** — Use alternate contact info, security questions, or ID verification\n2. **Look up account** — Search by phone number, alternate email, or name + DOB\n3. **Provide username/email** — Share the account email with the verified customer\n4. **Confirm login** — Have customer attempt to log in with the recovered username\n5. **Update contact info** — If needed, help update recovery email/phone on the account",
      "transitions" => [{"target_uuid" => pr_access_q}]
    },
    {
      "id" => pr_access_q,
      "type" => "question",
      "title" => "Was the customer able to regain access?",
      "question" => "Was the customer able to successfully regain access to their account?",
      "answer_type" => "yes_no",
      "variable_name" => "access_restored",
      "transitions" => [
        {"target_uuid" => pr_security_check, "condition" => "access_restored == 'yes'", "label" => "Access Restored"},
        {"target_uuid" => pr_escalate, "condition" => "access_restored == 'no'", "label" => "Still Locked Out"}
      ]
    },
    {
      "id" => pr_security_check,
      "type" => "action",
      "title" => "Post-Recovery Security Check",
      "action_type" => "instructions",
      "instructions" => "**Post-Recovery Security Check:**\n\n1. **Recommend password change** — Even if just reset, suggest a unique password not used elsewhere\n2. **Review recent activity** — Check for any unauthorized actions on the account\n3. **Enable 2FA** — If not already enabled, strongly recommend setting up 2FA\n4. **Review connected apps** — Revoke access for any unrecognized third-party apps\n5. **Update recovery info** — Ensure backup email and phone number are current",
      "transitions" => [{"target_uuid" => pr_resolved}]
    },
    {
      "id" => pr_resolved,
      "type" => "resolve",
      "title" => "Account Recovery Complete",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => pr_escalate,
      "type" => "escalate",
      "title" => "Escalate to Security Team",
      "target_type" => "team",
      "target_value" => "Account Security",
      "priority" => "high",
      "reason_required" => true,
      "notes" => "Recovery type: {{recovery_type}}. Customer unable to regain access after standard recovery process. Include all verification steps attempted and results.",
      "transitions" => []
    }
  ]
)

# --- Template 5: Complaint Handling & Resolution ---
ch_welcome = SecureRandom.uuid
ch_category = SecureRandom.uuid
ch_severity = SecureRandom.uuid
ch_investigate = SecureRandom.uuid
ch_desired = SecureRandom.uuid
ch_apology = SecureRandom.uuid
ch_refund = SecureRandom.uuid
ch_replacement = SecureRandom.uuid
ch_satisfied = SecureRandom.uuid
ch_resolved = SecureRandom.uuid
ch_escalate = SecureRandom.uuid
ch_escalate_resolve = SecureRandom.uuid

Template.find_or_initialize_by(name: "Complaint Handling & Resolution").update!(
  description: "Structured complaint handling with severity assessment, investigation, resolution options (apology, refund, replacement), and escalation paths for unsatisfied customers.",
  category: "complaints-retention",
  is_public: true,
  graph_mode: true,
  start_node_uuid: ch_welcome,
  workflow_data: [
    {
      "id" => ch_welcome,
      "type" => "message",
      "title" => "Complaint Received",
      "content" => "**Complaint Received**\n\nAcknowledge the customer's complaint with empathy:\n- \"I'm sorry to hear about this experience\"\n- \"I understand your frustration\"\n- \"Let me help resolve this for you\"\n\nExplain that you'll investigate and work toward a resolution.",
      "transitions" => [{"target_uuid" => ch_category}]
    },
    {
      "id" => ch_category,
      "type" => "question",
      "title" => "What is the complaint about?",
      "question" => "What category does this complaint fall into?",
      "answer_type" => "single_choice",
      "variable_name" => "complaint_category",
      "options" => [
        {"label" => "Product quality issue", "value" => "product_quality"},
        {"label" => "Service experience", "value" => "service_experience"},
        {"label" => "Billing error", "value" => "billing_error"},
        {"label" => "Delivery issue", "value" => "delivery_issue"},
        {"label" => "Staff behavior", "value" => "staff_behavior"},
        {"label" => "Other", "value" => "other"}
      ],
      "transitions" => [{"target_uuid" => ch_severity}]
    },
    {
      "id" => ch_severity,
      "type" => "question",
      "title" => "How severe is the impact?",
      "question" => "How would you rate the severity of the customer's complaint?",
      "answer_type" => "single_choice",
      "variable_name" => "severity",
      "options" => [
        {"label" => "Minor — inconvenience, no financial impact", "value" => "minor"},
        {"label" => "Moderate — some impact, workaround available", "value" => "moderate"},
        {"label" => "Major — significant impact, no workaround", "value" => "major"},
        {"label" => "Critical — urgent, potential legal/safety issue", "value" => "critical"}
      ],
      "transitions" => [
        {"target_uuid" => ch_escalate, "condition" => "severity == 'critical'", "label" => "Critical — Escalate"},
        {"target_uuid" => ch_investigate, "label" => "Investigate"}
      ]
    },
    {
      "id" => ch_investigate,
      "type" => "action",
      "title" => "Investigate Complaint",
      "action_type" => "instructions",
      "instructions" => "**Investigation Steps:**\n\n1. **Review account history** — Check previous interactions, orders, and complaints\n2. **Check related tickets** — Look for similar reports from other customers\n3. **Gather details** — Ask specific questions about what happened, when, and the impact\n4. **Verify claims** — Cross-reference with system records, delivery tracking, billing history\n5. **Document findings** — Record all relevant details for resolution decision",
      "transitions" => [{"target_uuid" => ch_desired}]
    },
    {
      "id" => ch_desired,
      "type" => "question",
      "title" => "What resolution does the customer want?",
      "question" => "What resolution is the customer seeking?",
      "answer_type" => "single_choice",
      "variable_name" => "desired_resolution",
      "options" => [
        {"label" => "Apology and acknowledgment", "value" => "apology"},
        {"label" => "Refund or account credit", "value" => "refund"},
        {"label" => "Replacement product/service", "value" => "replacement"},
        {"label" => "Wants to speak to a manager", "value" => "escalation"},
        {"label" => "Other", "value" => "other"}
      ],
      "transitions" => [
        {"target_uuid" => ch_apology, "condition" => "desired_resolution == 'apology'", "label" => "Apology"},
        {"target_uuid" => ch_refund, "condition" => "desired_resolution == 'refund'", "label" => "Refund/Credit"},
        {"target_uuid" => ch_replacement, "condition" => "desired_resolution == 'replacement'", "label" => "Replacement"},
        {"target_uuid" => ch_escalate, "condition" => "desired_resolution == 'escalation'", "label" => "Escalate"},
        {"target_uuid" => ch_apology, "label" => "Other"}
      ]
    },
    {
      "id" => ch_apology,
      "type" => "action",
      "title" => "Apply Resolution: Apology & Follow-up",
      "action_type" => "instructions",
      "instructions" => "**Apology & Follow-up Resolution:**\n\n1. **Sincere apology** — Acknowledge the specific issue and its impact\n2. **Explain what happened** — Be transparent about the cause (if known)\n3. **Document complaint** — Log in CRM with category: {{complaint_category}}, severity: {{severity}}\n4. **Schedule follow-up** — Set a reminder to check back with customer in 48 hours\n5. **Process improvement** — Flag for team review if it's a recurring issue",
      "transitions" => [{"target_uuid" => ch_satisfied}]
    },
    {
      "id" => ch_refund,
      "type" => "action",
      "title" => "Apply Resolution: Refund or Credit",
      "action_type" => "instructions",
      "instructions" => "**Refund/Credit Resolution:**\n\n1. **Process refund or credit** — Issue to original payment method or as account credit\n2. **Confirm amount** — Verify the refund amount with the customer\n3. **Document reason** — Log refund reason: {{complaint_category}}\n4. **Set expectations** — Refund processing time: 5-10 business days\n5. **Send confirmation** — Email receipt of refund/credit to customer",
      "transitions" => [{"target_uuid" => ch_satisfied}]
    },
    {
      "id" => ch_replacement,
      "type" => "action",
      "title" => "Apply Resolution: Replacement",
      "action_type" => "instructions",
      "instructions" => "**Replacement Resolution:**\n\n1. **Initiate replacement order** — Create order for replacement item/service\n2. **Provide tracking** — Share order number and expected delivery date\n3. **Return instructions** — If applicable, provide return label for defective item\n4. **Document** — Log replacement in system with original complaint reference\n5. **Follow up** — Set reminder to confirm replacement was received",
      "transitions" => [{"target_uuid" => ch_satisfied}]
    },
    {
      "id" => ch_satisfied,
      "type" => "question",
      "title" => "Is the customer satisfied with the resolution?",
      "question" => "Is the customer satisfied with the resolution provided?",
      "answer_type" => "yes_no",
      "variable_name" => "customer_satisfied",
      "transitions" => [
        {"target_uuid" => ch_resolved, "condition" => "customer_satisfied == 'yes'", "label" => "Satisfied"},
        {"target_uuid" => ch_escalate, "condition" => "customer_satisfied == 'no'", "label" => "Not Satisfied"}
      ]
    },
    {
      "id" => ch_resolved,
      "type" => "resolve",
      "title" => "Complaint Resolved",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => ch_escalate,
      "type" => "escalate",
      "title" => "Escalate Complaint",
      "target_type" => "supervisor",
      "target_value" => "Customer Relations Manager",
      "priority" => "high",
      "reason_required" => true,
      "notes" => "Complaint category: {{complaint_category}}, Severity: {{severity}}. Customer not satisfied with initial resolution or critical severity complaint. Include full complaint details and actions taken.",
      "transitions" => [{"target_uuid" => ch_escalate_resolve}]
    },
    {
      "id" => ch_escalate_resolve,
      "type" => "resolve",
      "title" => "Complaint Escalated",
      "resolution_type" => "escalated",
      "transitions" => []
    }
  ]
)

# --- Template 6: Cancellation & Retention ---
cr_welcome = SecureRandom.uuid
cr_account_id = SecureRandom.uuid
cr_reason = SecureRandom.uuid
cr_review = SecureRandom.uuid
cr_offer = SecureRandom.uuid
cr_accepted = SecureRandom.uuid
cr_apply_offer = SecureRandom.uuid
cr_retained = SecureRandom.uuid
cr_process_cancel = SecureRandom.uuid
cr_cancelled = SecureRandom.uuid
cr_escalate = SecureRandom.uuid

Template.find_or_initialize_by(name: "Cancellation & Retention").update!(
  description: "Handle cancellation requests with retention offers based on the reason for leaving. Includes account review, targeted offers, and graceful cancellation processing.",
  category: "complaints-retention",
  is_public: true,
  graph_mode: true,
  start_node_uuid: cr_welcome,
  workflow_data: [
    {
      "id" => cr_welcome,
      "type" => "message",
      "title" => "Cancellation Request",
      "content" => "**Cancellation Request Received**\n\nAcknowledge the customer's request professionally:\n- \"I understand you're considering canceling\"\n- \"I'd like to understand your experience so we can help\"\n- Do NOT be pushy or dismissive of their decision",
      "transitions" => [{"target_uuid" => cr_account_id}]
    },
    {
      "id" => cr_account_id,
      "type" => "question",
      "title" => "Customer's account number or email?",
      "question" => "What is the customer's account number or email address?",
      "answer_type" => "text",
      "variable_name" => "account_id",
      "transitions" => [{"target_uuid" => cr_reason}]
    },
    {
      "id" => cr_reason,
      "type" => "question",
      "title" => "Why does the customer want to cancel?",
      "question" => "What is the primary reason the customer wants to cancel?",
      "answer_type" => "single_choice",
      "variable_name" => "cancel_reason",
      "options" => [
        {"label" => "Too expensive", "value" => "too_expensive"},
        {"label" => "Not using the service enough", "value" => "not_using"},
        {"label" => "Missing features I need", "value" => "missing_features"},
        {"label" => "Switching to a competitor", "value" => "competitor"},
        {"label" => "Poor experience / service issues", "value" => "poor_experience"},
        {"label" => "Other reason", "value" => "other"}
      ],
      "transitions" => [
        {"target_uuid" => cr_escalate, "condition" => "cancel_reason == 'poor_experience'", "label" => "Poor Experience"},
        {"target_uuid" => cr_review, "label" => "Review Account"}
      ]
    },
    {
      "id" => cr_review,
      "type" => "action",
      "title" => "Review Account & Usage",
      "action_type" => "instructions",
      "instructions" => "**Account Review:**\n\n1. **Check current plan** — What plan are they on? Is there a cheaper option?\n2. **Review usage** — How actively have they been using the service?\n3. **Check billing history** — Any recent price increases or failed payments?\n4. **Note tenure** — How long have they been a customer?\n5. **Check for open issues** — Any unresolved support tickets that may be driving the cancellation?",
      "transitions" => [{"target_uuid" => cr_offer}]
    },
    {
      "id" => cr_offer,
      "type" => "action",
      "title" => "Present Retention Offer",
      "action_type" => "instructions",
      "instructions" => "**Retention Offer Based on Reason:**\n\n**Too expensive:** Offer 20-30% discount for 3 months, or suggest a lower-tier plan\n\n**Not using:** Offer a plan downgrade to reduce cost, highlight underused features\n\n**Missing features:** Share product roadmap highlights, offer to log as feature request with priority\n\n**Competitor:** Ask what the competitor offers that we don't, match if possible\n\n**Other:** Listen carefully, address the specific concern, offer a personalized solution\n\nPresent the offer naturally, not as a script. Be genuine.",
      "transitions" => [{"target_uuid" => cr_accepted}]
    },
    {
      "id" => cr_accepted,
      "type" => "question",
      "title" => "Did the customer accept the retention offer?",
      "question" => "Did the customer accept the retention offer?",
      "answer_type" => "yes_no",
      "variable_name" => "retention_accepted",
      "transitions" => [
        {"target_uuid" => cr_apply_offer, "condition" => "retention_accepted == 'yes'", "label" => "Accepted"},
        {"target_uuid" => cr_process_cancel, "condition" => "retention_accepted == 'no'", "label" => "Declined"}
      ]
    },
    {
      "id" => cr_apply_offer,
      "type" => "action",
      "title" => "Apply Retention Offer",
      "action_type" => "instructions",
      "instructions" => "**Apply the Retention Offer:**\n\n1. **Process the change** — Apply discount, change plan, or schedule follow-up as agreed\n2. **Confirm with customer** — Verify the changes are what they expected\n3. **Document** — Log the retention offer details and reason in CRM\n4. **Set follow-up** — Schedule a check-in in 30 days to ensure satisfaction\n5. **Send confirmation** — Email summary of changes made to the account",
      "transitions" => [{"target_uuid" => cr_retained}]
    },
    {
      "id" => cr_retained,
      "type" => "resolve",
      "title" => "Customer Retained",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => cr_process_cancel,
      "type" => "action",
      "title" => "Process Cancellation",
      "action_type" => "instructions",
      "instructions" => "**Process Cancellation:**\n\n1. **Confirm cancellation date** — End of current billing period or immediate\n2. **Explain final billing** — Any remaining charges or prorated refunds\n3. **Offer data export** — Help customer download their data before account closure\n4. **Process cancellation** — Submit the cancellation request in the system\n5. **Send confirmation** — Email cancellation confirmation with effective date\n6. **Leave door open** — \"We'd love to have you back anytime\"",
      "transitions" => [{"target_uuid" => cr_cancelled}]
    },
    {
      "id" => cr_cancelled,
      "type" => "resolve",
      "title" => "Cancellation Processed",
      "resolution_type" => "other",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => cr_escalate,
      "type" => "escalate",
      "title" => "Escalate to Retention Specialist",
      "target_type" => "team",
      "target_value" => "Customer Retention",
      "priority" => "medium",
      "reason_required" => true,
      "notes" => "Cancel reason: {{cancel_reason}}. Account: {{account_id}}. Customer reported poor experience — needs service recovery before retention offer.",
      "transitions" => []
    }
  ]
)

# --- Template 7: Inbound Sales Inquiry ---
si_welcome = SecureRandom.uuid
si_caller_info = SecureRandom.uuid
si_inquiry_type = SecureRandom.uuid
si_team_size = SecureRandom.uuid
si_present = SecureRandom.uuid
si_interest = SecureRandom.uuid
si_close = SecureRandom.uuid
si_demo = SecureRandom.uuid
si_sale_complete = SecureRandom.uuid
si_followup_resolve = SecureRandom.uuid

Template.find_or_initialize_by(name: "Inbound Sales Inquiry").update!(
  description: "Qualify inbound sales leads, present solutions based on needs and team size, and close or schedule follow-up demos.",
  category: "sales-onboarding",
  is_public: true,
  graph_mode: true,
  start_node_uuid: si_welcome,
  workflow_data: [
    {
      "id" => si_welcome,
      "type" => "message",
      "title" => "Inbound Sales Inquiry",
      "content" => "**Inbound Sales Inquiry**\n\nGreet the caller warmly and build rapport:\n- \"Thank you for reaching out to us!\"\n- \"I'd love to learn more about what you're looking for\"\n\nGather: Caller's name, company name, how they heard about us.",
      "transitions" => [{"target_uuid" => si_caller_info}]
    },
    {
      "id" => si_caller_info,
      "type" => "question",
      "title" => "Caller's name and company?",
      "question" => "What is the caller's name and company?",
      "answer_type" => "text",
      "variable_name" => "caller_info",
      "transitions" => [{"target_uuid" => si_inquiry_type}]
    },
    {
      "id" => si_inquiry_type,
      "type" => "question",
      "title" => "What is the caller looking for?",
      "question" => "What type of inquiry is this?",
      "answer_type" => "single_choice",
      "variable_name" => "inquiry_type",
      "options" => [
        {"label" => "New service / getting started", "value" => "new_service"},
        {"label" => "Upgrade existing plan", "value" => "upgrade"},
        {"label" => "Pricing information", "value" => "pricing_info"},
        {"label" => "Request a demo", "value" => "demo_request"},
        {"label" => "General inquiry", "value" => "general_inquiry"}
      ],
      "transitions" => [{"target_uuid" => si_team_size}]
    },
    {
      "id" => si_team_size,
      "type" => "question",
      "title" => "Team / company size?",
      "question" => "What is the caller's team or company size?",
      "answer_type" => "single_choice",
      "variable_name" => "team_size",
      "options" => [
        {"label" => "Individual / solo", "value" => "individual"},
        {"label" => "Small team (2-10)", "value" => "small_team_2_10"},
        {"label" => "Medium team (11-50)", "value" => "medium_team_11_50"},
        {"label" => "Large team (50+)", "value" => "large_team_50_plus"}
      ],
      "transitions" => [{"target_uuid" => si_present}]
    },
    {
      "id" => si_present,
      "type" => "action",
      "title" => "Present Solution",
      "action_type" => "instructions",
      "instructions" => "**Present the Right Solution:**\n\n1. **Match needs to plan** — Based on inquiry type ({{inquiry_type}}) and team size ({{team_size}})\n2. **Highlight relevant features** — Focus on what solves their specific pain points\n3. **Share pricing** — Provide transparent pricing based on team size\n4. **Show social proof** — Mention similar companies using the product\n5. **Address concerns** — Listen for objections and address them proactively\n\n**Pricing guidance by team size:**\n- Individual: Starter plan\n- Small team: Team plan\n- Medium team: Business plan\n- Large team: Enterprise (custom pricing)",
      "transitions" => [{"target_uuid" => si_interest}]
    },
    {
      "id" => si_interest,
      "type" => "question",
      "title" => "Is the caller interested in moving forward?",
      "question" => "What is the caller's interest level after the presentation?",
      "answer_type" => "single_choice",
      "variable_name" => "interest_level",
      "options" => [
        {"label" => "Ready to buy / sign up now", "value" => "ready_to_buy"},
        {"label" => "Wants a demo first", "value" => "needs_demo"},
        {"label" => "Needs internal approval", "value" => "needs_approval"},
        {"label" => "Not interested at this time", "value" => "not_interested"}
      ],
      "transitions" => [
        {"target_uuid" => si_close, "condition" => "interest_level == 'ready_to_buy'", "label" => "Close Sale"},
        {"target_uuid" => si_demo, "condition" => "interest_level == 'needs_demo'", "label" => "Schedule Demo"},
        {"target_uuid" => si_demo, "condition" => "interest_level == 'needs_approval'", "label" => "Schedule Follow-up"},
        {"target_uuid" => si_followup_resolve, "condition" => "interest_level == 'not_interested'", "label" => "Not Interested"}
      ]
    },
    {
      "id" => si_close,
      "type" => "action",
      "title" => "Close Sale",
      "action_type" => "instructions",
      "instructions" => "**Close the Sale:**\n\n1. **Walk through signup** — Guide caller through account creation\n2. **Apply promotions** — Check for any active promotions or discounts\n3. **Confirm payment** — Process payment and confirm billing details\n4. **Set up account** — Ensure account is provisioned and accessible\n5. **Welcome email** — Trigger welcome email with getting started guide\n6. **Schedule onboarding** — Offer an onboarding call within the first week",
      "transitions" => [{"target_uuid" => si_sale_complete}]
    },
    {
      "id" => si_demo,
      "type" => "action",
      "title" => "Schedule Demo / Follow-up",
      "action_type" => "instructions",
      "instructions" => "**Schedule Demo or Follow-up:**\n\n1. **Book demo** — Use calendar link to schedule a personalized demo\n2. **Send materials** — Email product overview, case studies, and pricing sheet\n3. **Set follow-up reminder** — CRM reminder 1 day before and 2 days after demo\n4. **Add to pipeline** — Log in CRM as qualified lead with stage and expected close date\n5. **Confirm details** — Send calendar invite with dial-in/video link",
      "transitions" => [{"target_uuid" => si_followup_resolve}]
    },
    {
      "id" => si_sale_complete,
      "type" => "resolve",
      "title" => "Sale Completed",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    },
    {
      "id" => si_followup_resolve,
      "type" => "resolve",
      "title" => "Follow-up Scheduled",
      "resolution_type" => "other",
      "notes_required" => true,
      "transitions" => []
    }
  ]
)

# --- Template 8: New Customer Onboarding Call ---
oc_welcome = SecureRandom.uuid
oc_name = SecureRandom.uuid
oc_setup_done = SecureRandom.uuid
oc_guide_setup = SecureRandom.uuid
oc_experience = SecureRandom.uuid
oc_beginner = SecureRandom.uuid
oc_experienced = SecureRandom.uuid
oc_next_steps = SecureRandom.uuid
oc_complete = SecureRandom.uuid

Template.find_or_initialize_by(name: "New Customer Onboarding Call").update!(
  description: "Welcome new customers, verify account setup, provide experience-appropriate feature walkthroughs, and set expectations for ongoing support.",
  category: "sales-onboarding",
  is_public: true,
  graph_mode: true,
  start_node_uuid: oc_welcome,
  workflow_data: [
    {
      "id" => oc_welcome,
      "type" => "message",
      "title" => "New Customer Onboarding Call",
      "content" => "**Welcome to Your Onboarding Call!**\n\nCongratulations on signing up! This call will cover:\n- Verifying your account setup is complete\n- Walking through key features based on your experience\n- Setting expectations for support and next steps\n- Scheduling a follow-up check-in\n\nLet's get started!",
      "transitions" => [{"target_uuid" => oc_name}]
    },
    {
      "id" => oc_name,
      "type" => "question",
      "title" => "What is the customer's name?",
      "question" => "What is the customer's name?",
      "answer_type" => "text",
      "variable_name" => "customer_name",
      "transitions" => [{"target_uuid" => oc_setup_done}]
    },
    {
      "id" => oc_setup_done,
      "type" => "question",
      "title" => "Has the customer completed initial account setup?",
      "question" => "Has {{customer_name}} completed the initial account setup (email verification, profile, basic settings)?",
      "answer_type" => "yes_no",
      "variable_name" => "setup_done",
      "transitions" => [
        {"target_uuid" => oc_experience, "condition" => "setup_done == 'yes'", "label" => "Setup Complete"},
        {"target_uuid" => oc_guide_setup, "condition" => "setup_done == 'no'", "label" => "Needs Setup"}
      ]
    },
    {
      "id" => oc_guide_setup,
      "type" => "action",
      "title" => "Guide Account Setup",
      "action_type" => "instructions",
      "instructions" => "**Walk Through Account Setup:**\n\n1. **Email verification** — Check if verification email was received, resend if needed\n2. **Profile completion** — Help fill in name, role, team info, and timezone\n3. **Basic settings** — Configure notification preferences and default options\n4. **Security** — Recommend enabling 2FA, setting a strong password\n5. **Confirm** — Verify they can log in and see the dashboard",
      "transitions" => [{"target_uuid" => oc_experience}]
    },
    {
      "id" => oc_experience,
      "type" => "question",
      "title" => "How familiar is the customer with similar tools?",
      "question" => "How would {{customer_name}} rate their familiarity with similar tools?",
      "answer_type" => "single_choice",
      "variable_name" => "experience",
      "options" => [
        {"label" => "Beginner — first time using this type of tool", "value" => "beginner"},
        {"label" => "Intermediate — some experience with similar tools", "value" => "intermediate"},
        {"label" => "Advanced — very familiar with similar tools", "value" => "advanced"}
      ],
      "transitions" => [
        {"target_uuid" => oc_beginner, "condition" => "experience == 'beginner'", "label" => "Beginner"},
        {"target_uuid" => oc_experienced, "condition" => "experience == 'intermediate'", "label" => "Intermediate"},
        {"target_uuid" => oc_experienced, "condition" => "experience == 'advanced'", "label" => "Advanced"}
      ]
    },
    {
      "id" => oc_beginner,
      "type" => "message",
      "title" => "Feature Walkthrough: Beginner",
      "content" => "**Detailed Feature Walkthrough for {{customer_name}}**\n\nShare your screen and walk through:\n\n1. **Dashboard overview** — Explain each section and what it shows\n2. **Navigation** — Show the main menu, how to find things\n3. **Key features** — Demonstrate the 3 most-used features step by step\n4. **Getting help** — Show where to find help docs, tutorials, and support chat\n5. **Practice together** — Have them try creating their first item while you watch\n\nEncourage questions throughout. Go at their pace.",
      "transitions" => [{"target_uuid" => oc_next_steps}]
    },
    {
      "id" => oc_experienced,
      "type" => "message",
      "title" => "Feature Walkthrough: Experienced",
      "content" => "**Quick Feature Overview for {{customer_name}}**\n\nFocus on what's different about our platform:\n\n1. **Advanced features** — Highlight power-user features and shortcuts\n2. **Integrations** — Show available integrations and API access\n3. **Customization** — Demonstrate advanced settings and configuration\n4. **Keyboard shortcuts** — Share the shortcuts cheat sheet\n5. **Migration** — If coming from a competitor, help with data import\n\nKeep it concise — they know the basics.",
      "transitions" => [{"target_uuid" => oc_next_steps}]
    },
    {
      "id" => oc_next_steps,
      "type" => "action",
      "title" => "Set Expectations & Next Steps",
      "action_type" => "instructions",
      "instructions" => "**Wrap Up the Onboarding Call:**\n\n1. **Support channels** — Email, chat, phone hours, and response times\n2. **Schedule check-in** — Book a 2-week follow-up call to see how they're doing\n3. **Share resources** — Send help docs link, video tutorials, and community forum invite\n4. **Set goals** — Help them define what success looks like in the first 30 days\n5. **Thank them** — \"We're excited to have you on board, {{customer_name}}!\"",
      "transitions" => [{"target_uuid" => oc_complete}]
    },
    {
      "id" => oc_complete,
      "type" => "resolve",
      "title" => "Onboarding Complete",
      "resolution_type" => "success",
      "notes_required" => true,
      "transitions" => []
    }
  ]
)

# Clean up old templates that have been replaced
old_template_names = ["Email Troubleshooting", "Refund Process", "Customer Onboarding", "Support Ticket Triage"]
Template.where(name: old_template_names).destroy_all

puts "Template library seeded successfully (8 Call/Chat Center Templates)!"
puts "   Troubleshooting:"
puts "     - Internet Connectivity Troubleshooting"
puts "     - Email Setup & Configuration"
puts "   Account Management:"
puts "     - Account Verification & Security"
puts "     - Password Reset & Account Recovery"
puts "   Complaints & Retention:"
puts "     - Complaint Handling & Resolution"
puts "     - Cancellation & Retention"
puts "   Sales & Onboarding:"
puts "     - Inbound Sales Inquiry"
puts "     - New Customer Onboarding Call"
