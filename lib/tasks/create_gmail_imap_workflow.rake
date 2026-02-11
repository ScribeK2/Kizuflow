namespace :workflows do
  desc "Create Gmail IMAP Android workflow template"
  task create_gmail_imap_workflow: :environment do
    # Use the user email from environment variable or default to first user
    user_email = ENV['USER_EMAIL'] || nil
    user = user_email ? User.find_by(email: user_email) : User.first

    if user.nil?
      puts "❌ Error: No user found."
      puts "   Either set USER_EMAIL environment variable: USER_EMAIL=your@email.com rails workflows:create_gmail_imap_workflow"
      puts "   Or ensure at least one user exists in the database."
      exit 1
    end

    puts "Creating workflow for user: #{user.email}"

    workflow = Workflow.find_or_create_by!(title: "Connecting A Business Email to Gmail using IMAP on Android") do |w|
      w.user = user
      w.description = "A comprehensive guide for CSRs to help clients connect their business email hosted with us to Gmail on Android using IMAP. This flow covers verification, setup, configuration, and troubleshooting."

      w.steps = [
        # Step 1: Collect client information
        {
          "type" => "question",
          "title" => "Client Email Address",
          "description" => "Collect the client's business email address",
          "question" => "What is the client's business email address?",
          "answer_type" => "text",
          "variable_name" => "client_email"
        },

        # Step 2: Verify domain
        {
          "type" => "question",
          "title" => "Client Domain",
          "description" => "Extract and verify the domain from the email address",
          "question" => "What domain is associated with this email? (Extract from email address)",
          "answer_type" => "text",
          "variable_name" => "client_domain"
        },

        # Step 3: Check if Gmail app is installed
        {
          "type" => "question",
          "title" => "Gmail App Installed",
          "description" => "Verify the client has Gmail app installed on their Android device",
          "question" => "Does the client have the Gmail app installed on their Android device?",
          "answer_type" => "yes_no",
          "variable_name" => "gmail_installed"
        },

        # Step 4: Decision - Gmail installed or not
        {
          "type" => "decision",
          "title" => "Gmail App Check",
          "description" => "Route based on whether Gmail is installed",
          "branches" => [
            {
              "condition" => "gmail_installed == 'yes'",
              "path" => "Open Gmail App"
            }
          ],
          "else_path" => "Install Gmail App"
        },

        # Step 5: Install Gmail App (if needed)
        {
          "type" => "action",
          "title" => "Install Gmail App",
          "description" => "Guide client to install Gmail app from Play Store",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. Open Google Play Store on their Android device\n2. Search for 'Gmail'\n3. Tap 'Install' and wait for installation to complete\n4. Confirm when installation is finished",
          "attachments" => []
        },

        # Step 6: Open Gmail App
        {
          "type" => "action",
          "title" => "Open Gmail App",
          "description" => "Guide client to open Gmail app",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. Locate the Gmail app icon on their Android device\n2. Tap to open the Gmail app\n3. If this is their first time, they may see a welcome screen\n4. Confirm when they have the Gmail app open",
          "attachments" => []
        },

        # Step 7: Navigate to Add Account
        {
          "type" => "action",
          "title" => "Navigate to Add Account",
          "description" => "Guide client to the account settings",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. Tap the menu icon (three horizontal lines) in the top left corner\n2. Scroll down and tap 'Settings'\n3. Tap 'Add account'\n4. Select 'Other (Personal)' or 'Personal (IMAP)'\n5. Confirm when they see the email address entry screen",
          "attachments" => []
        },

        # Step 8: Enter Email Address
        {
          "type" => "question",
          "title" => "Email Address Confirmation",
          "description" => "Verify client entered their email correctly",
          "question" => "Did the client enter their email address correctly?",
          "answer_type" => "yes_no",
          "variable_name" => "email_entered"
        },

        # Step 9: Decision - Email entered correctly
        {
          "type" => "decision",
          "title" => "Email Entry Check",
          "description" => "Route based on email entry",
          "branches" => [
            {
              "condition" => "email_entered == 'yes'",
              "path" => "Manual Setup Option"
            }
          ],
          "else_path" => "Enter Email Address"
        },

        # Step 10: Re-enter Email (if needed)
        {
          "type" => "action",
          "title" => "Enter Email Address",
          "description" => "Guide client to correct their email entry",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. Verify they entered the correct email address (use the client_email variable)\n2. Correct any typos\n3. Tap 'Next' when correct",
          "attachments" => []
        },

        # Step 11: Choose Manual Setup
        {
          "type" => "action",
          "title" => "Manual Setup Option",
          "description" => "Guide client to choose manual setup",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. When Gmail asks 'Which account type?', select 'Personal (IMAP)'\n2. If asked for password, they can enter it now or skip\n3. Look for 'Manual setup' or 'Advanced' option\n4. Select 'Personal (IMAP)' if not already selected\n5. Confirm when they see the server settings screen",
          "attachments" => []
        },

        # Step 12: Configure IMAP Settings
        {
          "type" => "action",
          "title" => "Configure IMAP (Incoming) Settings",
          "description" => "Guide client through IMAP server configuration",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to enter the following IMAP settings:\n\nIncoming Server Settings:\n• Server: imap.[client_domain] (replace [client_domain] with the actual domain)\n• Port: 993\n• Security type: SSL/TLS\n• Username: [client_email] (full email address)\n• Password: [client's email password]\n\nAfter entering these settings, tap 'Next'",
          "attachments" => []
        },

        # Step 13: Verify IMAP Connection
        {
          "type" => "question",
          "title" => "IMAP Connection Successful",
          "description" => "Check if IMAP connection was successful",
          "question" => "Did the IMAP connection test succeed?",
          "answer_type" => "yes_no",
          "variable_name" => "imap_success"
        },

        # Step 14: Decision - IMAP success
        {
          "type" => "decision",
          "title" => "IMAP Connection Check",
          "description" => "Route based on IMAP connection result",
          "branches" => [
            {
              "condition" => "imap_success == 'yes'",
              "path" => "Configure SMTP (Outgoing) Settings"
            }
          ],
          "else_path" => "Troubleshoot IMAP Connection"
        },

        # Step 15: Troubleshoot IMAP
        {
          "type" => "action",
          "title" => "Troubleshoot IMAP Connection",
          "description" => "Help troubleshoot IMAP connection issues",
          "action_type" => "instructions",
          "instructions" => "Common IMAP issues to check:\n\n1. Verify server address: imap.[client_domain] (should match the domain from step 2)\n2. Verify port is 993\n3. Verify security type is SSL/TLS (not STARTTLS)\n4. Verify username is the full email address\n5. Verify password is correct\n6. Check if client's domain email is active\n7. Verify firewall/network isn't blocking port 993\n\nHave client try again with corrected settings.",
          "attachments" => []
        },

        # Step 16: Configure SMTP Settings
        {
          "type" => "action",
          "title" => "Configure SMTP (Outgoing) Settings",
          "description" => "Guide client through SMTP server configuration",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to enter the following SMTP settings:\n\nOutgoing Server Settings:\n• Server: smtp.[client_domain] (replace [client_domain] with the actual domain)\n• Port: 465\n• Security type: SSL/TLS\n• Username: [client_email] (full email address)\n• Password: [client's email password]\n• Require sign-in: Yes\n\nAfter entering these settings, tap 'Next'",
          "attachments" => []
        },

        # Step 17: Verify SMTP Connection
        {
          "type" => "question",
          "title" => "SMTP Connection Successful",
          "description" => "Check if SMTP connection was successful",
          "question" => "Did the SMTP connection test succeed?",
          "answer_type" => "yes_no",
          "variable_name" => "smtp_success"
        },

        # Step 18: Decision - SMTP success
        {
          "type" => "decision",
          "title" => "SMTP Connection Check",
          "description" => "Route based on SMTP connection result",
          "branches" => [
            {
              "condition" => "smtp_success == 'yes'",
              "path" => "Account Setup Complete"
            }
          ],
          "else_path" => "Troubleshoot SMTP Connection"
        },

        # Step 19: Troubleshoot SMTP
        {
          "type" => "action",
          "title" => "Troubleshoot SMTP Connection",
          "description" => "Help troubleshoot SMTP connection issues",
          "action_type" => "instructions",
          "instructions" => "Common SMTP issues to check:\n\n1. Verify server address: smtp.[client_domain] (should match the domain from step 2)\n2. Verify port is 465\n3. Verify security type is SSL/TLS (not STARTTLS)\n4. Verify username is the full email address\n5. Verify password is correct\n6. Ensure 'Require sign-in' is enabled\n7. Check if client's domain email is active\n8. Verify firewall/network isn't blocking port 465\n\nHave client try again with corrected settings.",
          "attachments" => []
        },

        # Step 20: Account Setup Options
        {
          "type" => "action",
          "title" => "Account Setup Complete",
          "description" => "Configure account name and sync options",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. Enter an account name (e.g., 'Work Email' or 'Business Email')\n2. Review sync settings:\n   - Sync frequency: Every 15 minutes (recommended)\n   - Sync email: Yes\n   - Sync contacts: Optional\n   - Sync calendar: Optional\n3. Tap 'Next' or 'Done' to complete setup",
          "attachments" => []
        },

        # Step 21: Test Email Functionality
        {
          "type" => "action",
          "title" => "Test Email Functionality",
          "description" => "Verify the email account is working correctly",
          "action_type" => "instructions",
          "instructions" => "Instruct the client to:\n1. Send a test email from their business account to their personal email\n2. Check if they receive the test email\n3. Try replying to the test email\n4. Verify sent emails appear in Sent folder\n5. Confirm when all tests are successful",
          "attachments" => []
        },

        # Step 22: Verification Complete
        {
          "type" => "question",
          "title" => "Email Functionality Verified",
          "description" => "Confirm email is working correctly",
          "question" => "Are all email functions working correctly? (sending, receiving, folders)",
          "answer_type" => "yes_no",
          "variable_name" => "email_working"
        },

        # Step 23: Final Decision
        {
          "type" => "decision",
          "title" => "Setup Verification",
          "description" => "Route based on final verification",
          "branches" => [
            {
              "condition" => "email_working == 'yes'",
              "path" => "Setup Complete - Success"
            }
          ],
          "else_path" => "Additional Troubleshooting"
        },

        # Step 24: Additional Troubleshooting
        {
          "type" => "action",
          "title" => "Additional Troubleshooting",
          "description" => "Further troubleshooting steps",
          "action_type" => "instructions",
          "instructions" => "If email is still not working:\n\n1. Verify all server settings are correct:\n   - IMAP: imap.[client_domain]:993 (SSL/TLS)\n   - SMTP: smtp.[client_domain]:465 (SSL/TLS)\n\n2. Check account status:\n   - Verify email account is active in hosting panel\n   - Check if account has been suspended\n   - Verify password hasn't changed\n\n3. Try removing and re-adding the account\n\n4. Check Android system settings:\n   - Ensure date/time is correct\n   - Check battery optimization settings\n   - Verify network connection\n\nIf issues persist, escalate to technical support.",
          "attachments" => []
        },

        # Step 25: Success
        {
          "type" => "action",
          "title" => "Setup Complete - Success",
          "description" => "Confirm successful setup and provide next steps",
          "action_type" => "instructions",
          "instructions" => "Great! The email account has been successfully configured.\n\nInform the client:\n1. Their business email is now connected to Gmail on Android\n2. They can send and receive emails using the Gmail app\n3. Emails will sync automatically every 15 minutes\n4. They can access their email from the Gmail app at any time\n5. If they experience any issues, they can contact support\n\nDocument the successful setup in the client's account.",
          "attachments" => []
        }
      ]
    end

    puts "✅ Created workflow: #{workflow.title}"
    puts "   Steps: #{workflow.steps.length}"
    puts "   ID: #{workflow.id}"
    puts "\nTo view/edit: rails server then navigate to /workflows/#{workflow.id}/edit"
  end
end
