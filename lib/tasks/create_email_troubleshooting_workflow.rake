namespace :workflows do
  desc "Create Ultimate External Email Client Troubleshooting workflow - comprehensive stress test"
  task create_email_troubleshooting: :environment do
    # ============================================================================
    # ULTIMATE EXTERNAL EMAIL CLIENT TROUBLESHOOTING WORKFLOW
    # ============================================================================
    # A comprehensive stress test workflow demonstrating Kizuflow's power
    # Covers: Apple Mail, Gmail, Microsoft Outlook
    # Platforms: Android, iOS, Windows, macOS, Web Browsers
    # Protocols: IMAP, POP, Exchange
    #
    # IMPORTANT: Steps are ordered so each branch's steps are CONTIGUOUS.
    # This ensures proper flow after decision steps route to different paths.
    #
    # Research Sources (as of January 2026):
    # - Apple Support: support.apple.com/kb/ht5361
    # - Gmail: Gmail discontinued POP "Check mail from other accounts" (Jan 2026)
    # - Microsoft: learn.microsoft.com - Basic Auth deprecated, OAuth 2.0 required
    # - Standard ports: IMAP 993 (SSL), POP 995 (SSL), SMTP 465 (SSL) / 587 (STARTTLS)
    # ============================================================================

    user_email = ENV['USER_EMAIL'] || nil
    user = user_email ? User.find_by(email: user_email) : User.first

    if user.nil?
      puts "❌ Error: No user found."
      puts "   Set USER_EMAIL environment variable: USER_EMAIL=your@email.com rails workflows:create_email_troubleshooting"
      puts "   Or ensure at least one user exists in the database."
      exit 1
    end

    puts "🚀 Creating Ultimate External Email Client Troubleshooting Workflow"
    puts "   User: #{user.email}"
    puts ""

    workflow = Workflow.find_or_initialize_by(title: "Ultimate External Email Client Troubleshooting")
    workflow.user = user
    workflow.is_public = true
    workflow.status = 'published'
    workflow.description = <<~DESC
      <h2>📧 Ultimate External Email Client Troubleshooting Guide</h2>
      <p><strong>A comprehensive workflow for setting up and troubleshooting external email accounts across all major clients and devices.</strong></p>

      <h3>Supported Email Clients:</h3>
      <ul>
        <li>🍎 <strong>Apple Mail</strong> (iOS, macOS)</li>
        <li>📱 <strong>Gmail App & Web</strong> (Android, iOS, Chrome, Safari)</li>
        <li>💼 <strong>Microsoft Outlook</strong> (Windows, macOS, iOS, Android, Web)</li>
      </ul>

      <h3>Protocol Support:</h3>
      <ul>
        <li>IMAP (Port 993 SSL/TLS) - Recommended</li>
        <li>POP3 (Port 995 SSL/TLS) - Legacy support</li>
        <li>Exchange (ActiveSync/EWS)</li>
        <li>SMTP (Port 465 SSL or 587 STARTTLS)</li>
      </ul>

      <h3>Key 2026 Updates:</h3>
      <ul>
        <li>⚠️ Gmail discontinued POP "Check mail from other accounts" feature</li>
        <li>⚠️ Microsoft deprecated Basic Authentication - OAuth 2.0 required</li>
        <li>⚠️ Two-factor authentication may require app-specific passwords</li>
      </ul>

      <p><em>This workflow demonstrates Kizuflow's ability to handle complex, multi-branching troubleshooting scenarios with 55+ detailed steps.</em></p>
    DESC

    workflow.steps = [
      # ============================================================================
      # SECTION 1: WELCOME & CLIENT SELECTION
      # ============================================================================
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Welcome - Email Troubleshooting Guide",
        "description" => "Introduction to the email setup and troubleshooting workflow",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Welcome to the Ultimate Email Troubleshooting Guide! 📧

          This workflow will guide you through:

          1. **Basic Setup** - Adding your external email account to your preferred client
          2. **Server Configuration** - IMAP/POP/SMTP settings with correct ports
          3. **Authentication** - Password, OAuth, and 2FA setup
          4. **Troubleshooting** - Common issues and their solutions

          ## Before We Begin

          Please have the following information ready:
          - Your email address
          - Your email password
          - Your email provider's server addresses (if known)

          ## Important 2026 Updates

          ⚠️ **Gmail Users**: Gmail no longer supports fetching from external accounts via POP in the web interface.
          ⚠️ **Microsoft/Outlook Users**: Basic Authentication is deprecated. OAuth 2.0 is now required.

          Click **Next** when you're ready to begin.
        INST
      },

      # Step 2: Select Email Client
      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Select Your Email Client",
        "description" => "Choose which email application you want to configure",
        "question" => "Which email client are you trying to set up?",
        "answer_type" => "single_choice",
        "variable_name" => "client",
        "options" => [
          { "label" => "🍎 Apple Mail", "value" => "apple_mail" },
          { "label" => "📱 Gmail (App or Web)", "value" => "gmail" },
          { "label" => "💼 Microsoft Outlook", "value" => "outlook" }
        ]
      },

      # Step 3: Client Decision Branch
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Route to Client Setup",
        "description" => "Branch based on selected email client",
        "branches" => [
          { "condition" => "client == 'apple_mail'", "path" => "Select Device - Apple Mail" },
          { "condition" => "client == 'gmail'", "path" => "Select Device - Gmail" },
          { "condition" => "client == 'outlook'", "path" => "Select Device - Outlook" }
        ],
        "else_path" => "Select Device - Apple Mail"
      },

      # ============================================================================
      # APPLE MAIL COMPLETE PATH (Steps 4-12)
      # All Apple Mail steps are contiguous for proper routing
      # ============================================================================

      # Apple Mail Device Selection
      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Select Device - Apple Mail",
        "description" => "Choose your Apple device type",
        "question" => "Which device are you setting up Apple Mail on?",
        "answer_type" => "single_choice",
        "variable_name" => "device",
        "options" => [
          { "label" => "📱 iPhone/iPad (iOS)", "value" => "ios" },
          { "label" => "💻 Mac (macOS)", "value" => "macos" }
        ]
      },

      # Apple Mail Device Decision (immediately after device selection)
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Route Apple Mail Setup",
        "description" => "Branch based on Apple device type",
        "branches" => [
          { "condition" => "device == 'ios'", "path" => "Apple Mail - iOS Setup" },
          { "condition" => "device == 'macos'", "path" => "Apple Mail - macOS Setup" }
        ],
        "else_path" => "Apple Mail - iOS Setup"
      },

      # Apple Mail - iOS Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Apple Mail - iOS Setup",
        "description" => "Step-by-step setup for Apple Mail on iPhone/iPad",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up Apple Mail on iOS (iPhone/iPad) 📱

          ## Step 1: Open Settings
          1. Tap the **Settings** app on your home screen
          2. Scroll down and tap **Mail**
          3. Tap **Accounts**
          4. Tap **Add Account**

          ## Step 2: Select Account Type
          1. If your provider is listed (Google, Yahoo, etc.), select it
          2. For custom domains or IMAP/POP, tap **Other**
          3. Tap **Add Mail Account**

          ## Step 3: Enter Basic Information
          - **Name**: Your display name (e.g., John Smith)
          - **Email**: Your email address
          - **Password**: Your email password
          - **Description**: A label for this account (e.g., "Work Email")

          Tap **Next** to continue to server configuration.
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Apple Mail iOS - IMAP Configuration",
        "description" => "Configure IMAP settings for Apple Mail on iOS",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # IMAP Configuration for iOS Mail 📥

          ## Incoming Mail Server (IMAP)
          Enter these settings under **INCOMING MAIL SERVER**:

          | Setting | Value |
          |---------|-------|
          | **Host Name** | imap.yourdomain.com (or mail.yourdomain.com) |
          | **User Name** | Your full email address |
          | **Password** | Your email password |

          ## Advanced Settings (tap "Advanced")
          | Setting | Value |
          |---------|-------|
          | **Use SSL** | ✅ ON |
          | **Authentication** | Password |
          | **Server Port** | **993** |

          ⚠️ **2026 Note**: If you see an authentication error, your provider may require OAuth. Check if your email provider supports "Sign in with Google/Microsoft" options.
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Apple Mail iOS - SMTP Configuration",
        "description" => "Configure SMTP (outgoing) settings for Apple Mail on iOS",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # SMTP Configuration for iOS Mail 📤

          ## Outgoing Mail Server (SMTP)
          Enter these settings under **OUTGOING MAIL SERVER**:

          | Setting | Value |
          |---------|-------|
          | **Host Name** | smtp.yourdomain.com |
          | **User Name** | Your full email address |
          | **Password** | Your email password |

          ## Advanced SMTP Settings
          | Setting | Value |
          |---------|-------|
          | **Use SSL** | ✅ ON |
          | **Authentication** | Password |
          | **Server Port** | **465** (SSL) or **587** (STARTTLS) |

          ## Verify Settings
          1. Tap **Next** to verify settings
          2. Wait for connection test to complete
          3. If successful, tap **Save**

          💡 **Tip**: If port 465 doesn't work, try port 587 with STARTTLS enabled.
        INST
      },

      # Jump to verification after iOS setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Apple iOS Setup Complete",
        "description" => "Route to verification after iOS setup",
        "branches" => [
          { "condition" => "client == 'apple_mail'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Apple Mail - macOS Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Apple Mail - macOS Setup",
        "description" => "Step-by-step setup for Apple Mail on Mac",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up Apple Mail on macOS 💻

          ## Step 1: Open Mail Application
          1. Open **Mail** from your Applications folder or Dock
          2. If Mail isn't set up, you'll see the account setup wizard
          3. If Mail is already running: **Mail** menu → **Add Account...**

          ## Step 2: Select Account Type
          1. Choose **Other Mail Account...** for custom domains
          2. Or select your provider if listed (Google, Microsoft, Yahoo)

          ## Step 3: Enter Account Details
          - **Name**: Your display name
          - **Email Address**: Your full email address
          - **Password**: Your email password

          Click **Sign In** and wait for automatic configuration.

          ## Step 4: If Automatic Setup Fails
          macOS will prompt for manual settings if automatic detection fails.
          Continue to the next step for manual IMAP configuration.

          ⚠️ **2026 Update**: Apple Mail has known issues with Outlook/Microsoft 365 accounts after recent updates. If authentication fails repeatedly, try removing and re-adding the account.
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Apple Mail macOS - Server Configuration",
        "description" => "Configure IMAP and SMTP for Apple Mail on macOS",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Manual Server Configuration for macOS Mail ⚙️

          ## Incoming Mail Server (IMAP)
          | Setting | Value |
          |---------|-------|
          | **Mail Server** | imap.yourdomain.com |
          | **User Name** | Your full email address |
          | **Password** | Your password |
          | **Port** | **993** |
          | **TLS/SSL** | ✅ Enabled |
          | **Authentication** | Password |

          ## Outgoing Mail Server (SMTP)
          | Setting | Value |
          |---------|-------|
          | **Mail Server** | smtp.yourdomain.com |
          | **User Name** | Your full email address |
          | **Password** | Your password |
          | **Port** | **465** (SSL) or **587** (STARTTLS) |
          | **TLS/SSL** | ✅ Enabled |
          | **Authentication** | Password |

          ## Troubleshooting Tips for macOS
          1. **Certificate errors**: System Preferences → Date & Time → Ensure correct date/time
          2. **Keychain issues**: Open Keychain Access, search for your email, delete old entries
          3. **Connection refused**: Check if your firewall is blocking ports 993/465/587
        INST
      },

      # Jump to verification after macOS setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Apple macOS Setup Complete",
        "description" => "Route to verification after macOS setup",
        "branches" => [
          { "condition" => "client == 'apple_mail'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # ============================================================================
      # GMAIL COMPLETE PATH (Steps 13-22)
      # All Gmail steps are contiguous for proper routing
      # ============================================================================

      # Gmail Device Selection
      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Select Device - Gmail",
        "description" => "Choose your device type for Gmail",
        "question" => "Which device or platform are you using Gmail on?",
        "answer_type" => "single_choice",
        "variable_name" => "device",
        "options" => [
          { "label" => "🤖 Android Phone/Tablet", "value" => "android" },
          { "label" => "📱 iPhone/iPad (iOS)", "value" => "ios" },
          { "label" => "🌐 Web Browser (Chrome, Safari, etc.)", "value" => "web" }
        ]
      },

      # Gmail Device Decision (immediately after device selection)
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Route Gmail Setup",
        "description" => "Branch based on Gmail device type",
        "branches" => [
          { "condition" => "device == 'android'", "path" => "Gmail - Android Setup" },
          { "condition" => "device == 'ios'", "path" => "Gmail - iOS Setup" },
          { "condition" => "device == 'web'", "path" => "Gmail - Web Setup" }
        ],
        "else_path" => "Gmail - Android Setup"
      },

      # Gmail - Android Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Gmail - Android Setup",
        "description" => "Step-by-step setup for Gmail app on Android",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up External Email in Gmail App (Android) 🤖

          ## Step 1: Open Gmail App
          1. Open the **Gmail** app on your Android device
          2. Tap your **profile picture** or initial in the top right
          3. Tap **Add another account**

          ## Step 2: Choose Account Type
          1. Select **Other** for external IMAP/POP accounts
          2. For Microsoft accounts, you can try **Outlook, Hotmail, and Live**

          ## Step 3: Enter Email Address
          1. Enter your email address
          2. Tap **Next**
          3. Select **Personal (IMAP)** when prompted for account type

          ## Android Permissions Required
          ⚠️ Gmail may request the following permissions:
          - **Contacts**: To suggest recipients
          - **Storage**: For attachment handling
          - **Notifications**: For new mail alerts

          Grant these permissions for full functionality.
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Gmail Android - IMAP Configuration",
        "description" => "Configure IMAP settings for Gmail on Android",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # IMAP Configuration for Gmail Android 📱

          ## Incoming Server Settings
          | Setting | Value |
          |---------|-------|
          | **Username** | Your full email address |
          | **Password** | Your email password |
          | **Server** | imap.yourdomain.com |
          | **Port** | **993** |
          | **Security Type** | **SSL/TLS** |

          ## Outgoing Server Settings (SMTP)
          | Setting | Value |
          |---------|-------|
          | **SMTP Server** | smtp.yourdomain.com |
          | **Port** | **465** or **587** |
          | **Security Type** | **SSL/TLS** (465) or **STARTTLS** (587) |
          | **Require sign-in** | ✅ Yes |
          | **Username** | Your full email address |
          | **Password** | Your email password |

          ## Account Options
          - **Sync frequency**: Every 15 minutes (recommended)
          - **Notify me when email arrives**: ✅ Enabled
          - **Sync email from this account**: ✅ Enabled

          ⚠️ **2026 Note**: Gmail no longer supports POP "Check mail from other accounts" in web interface. Use the Gmail app for external account access.
        INST
      },

      # Jump to verification after Gmail Android setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Gmail Android Setup Complete",
        "description" => "Route to verification after Android setup",
        "branches" => [
          { "condition" => "client == 'gmail'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Gmail - iOS Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Gmail - iOS Setup",
        "description" => "Step-by-step setup for Gmail app on iPhone/iPad",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up External Email in Gmail App (iOS) 📱

          ## Step 1: Install/Open Gmail
          1. Download **Gmail** from the App Store if not installed
          2. Open the Gmail app
          3. Tap your profile picture in the top right
          4. Tap **Add another account**

          ## Step 2: Select Account Type
          1. Tap **Other (IMAP)** for external accounts
          2. Note: Gmail iOS supports adding external IMAP accounts

          ## Step 3: Enter Credentials
          1. Email: Your full email address
          2. Tap **Next**
          3. Enter your password
          4. Select **IMAP** as the account type

          ## iOS Privacy Settings
          ⚠️ Check these iOS settings if you have issues:
          - **Settings** → **Privacy & Security** → **Local Network** → Gmail: ✅ ON
          - **Settings** → **Gmail** → **Background App Refresh**: ✅ ON
          - **Settings** → **Notifications** → **Gmail**: Configure as desired
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Gmail iOS - Server Configuration",
        "description" => "Configure IMAP/SMTP for Gmail app on iOS",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Server Configuration for Gmail iOS 📧

          ## IMAP (Incoming) Settings
          | Setting | Value |
          |---------|-------|
          | **IMAP Server** | imap.yourdomain.com |
          | **Port** | **993** |
          | **Security** | **SSL** |
          | **Username** | Your full email address |

          ## SMTP (Outgoing) Settings
          | Setting | Value |
          |---------|-------|
          | **SMTP Server** | smtp.yourdomain.com |
          | **Port** | **465** (SSL) or **587** (TLS) |
          | **Security** | **SSL/TLS** |
          | **Username** | Your full email address |
          | **Authentication** | ✅ Required |

          ## Finishing Setup
          1. Tap **Next** to verify settings
          2. Choose what to sync (Mail, Contacts, Calendars, Notes)
          3. Tap **Save** to complete setup
        INST
      },

      # Jump to verification after Gmail iOS setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Gmail iOS Setup Complete",
        "description" => "Route to verification after Gmail iOS setup",
        "branches" => [
          { "condition" => "client == 'gmail'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Gmail - Web Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Gmail - Web Setup",
        "description" => "Setting up email access via Gmail web interface",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Gmail Web Interface - External Email Setup 🌐

          ## ⚠️ Important 2026 Update
          **Gmail has discontinued the "Check mail from other accounts (using POP3)" feature as of January 2026.**

          ## Alternative Options:

          ### Option 1: Email Forwarding (Recommended)
          Set up forwarding from your external email to Gmail:
          1. Log into your external email provider's web interface
          2. Find **Forwarding** or **Mail forwarding** settings
          3. Add your Gmail address as a forwarding destination
          4. Verify the forwarding address

          ### Option 2: Send Mail As
          You can still send email as your external address from Gmail:
          1. Go to Gmail → **Settings** ⚙️ → **See all settings**
          2. Click **Accounts and Import** tab
          3. Find **Send mail as** section
          4. Click **Add another email address**
          5. Enter your external email address
          6. Configure SMTP settings:
             - **SMTP Server**: smtp.yourdomain.com
             - **Port**: **587** (with TLS) or **465** (with SSL)
             - **Username**: Your full email address
             - **Password**: Your email password

          ### Option 3: Use Gmail Mobile App
          The Gmail mobile app (Android/iOS) still supports adding external IMAP accounts directly.
        INST
      },

      # Jump to verification after Gmail Web setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Gmail Web Setup Complete",
        "description" => "Route to verification after Gmail Web setup",
        "branches" => [
          { "condition" => "client == 'gmail'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # ============================================================================
      # OUTLOOK COMPLETE PATH (Steps 23-40)
      # All Outlook steps are contiguous for proper routing
      # ============================================================================

      # Outlook Device Selection
      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Select Device - Outlook",
        "description" => "Choose your device type for Outlook",
        "question" => "Which device or platform are you using Outlook on?",
        "answer_type" => "single_choice",
        "variable_name" => "device",
        "options" => [
          { "label" => "🖥️ Windows Desktop", "value" => "windows" },
          { "label" => "💻 Mac (macOS)", "value" => "macos" },
          { "label" => "📱 iPhone/iPad (iOS)", "value" => "ios" },
          { "label" => "🤖 Android Phone/Tablet", "value" => "android" },
          { "label" => "🌐 Web Browser (Outlook.com)", "value" => "web" }
        ]
      },

      # Outlook Device Decision (immediately after device selection)
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Route Outlook Setup",
        "description" => "Branch based on Outlook device type",
        "branches" => [
          { "condition" => "device == 'windows'", "path" => "Outlook - Windows Setup" },
          { "condition" => "device == 'macos'", "path" => "Outlook - macOS Setup" },
          { "condition" => "device == 'ios'", "path" => "Outlook - iOS Setup" },
          { "condition" => "device == 'android'", "path" => "Outlook - Android Setup" },
          { "condition" => "device == 'web'", "path" => "Outlook - Web Setup" }
        ],
        "else_path" => "Outlook - Windows Setup"
      },

      # Outlook - Windows Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Outlook - Windows Setup",
        "description" => "Step-by-step setup for Microsoft Outlook on Windows",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up External Email in Outlook for Windows 🖥️

          ## Step 1: Open Account Settings
          1. Open **Microsoft Outlook**
          2. Click **File** in the top menu
          3. Click **Add Account**

          ## Step 2: Enter Email Address
          1. Enter your email address
          2. Click **Advanced options**
          3. ✅ Check **Let me set up my account manually**
          4. Click **Connect**

          ## Step 3: Choose Account Type
          Select **IMAP** or **POP** based on your preference:
          - **IMAP**: Syncs emails across all devices (recommended)
          - **POP**: Downloads emails to this device only

          ## ⚠️ 2026 Authentication Update
          Microsoft has deprecated Basic Authentication. If you see authentication errors:
          1. Your email provider may need to support **OAuth 2.0**
          2. For providers without OAuth: Generate an **App Password** if 2FA is enabled
          3. Contact your email provider about modern authentication support
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Outlook Windows - IMAP Configuration",
        "description" => "Configure IMAP settings for Outlook on Windows",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # IMAP Configuration for Outlook Windows ⚙️

          ## Incoming Mail Settings
          | Setting | Value |
          |---------|-------|
          | **Server** | imap.yourdomain.com |
          | **Port** | **993** |
          | **Encryption method** | **SSL/TLS** |
          | **Require logon using SPA** | ❌ Unchecked (unless required) |

          ## Outgoing Mail Settings
          | Setting | Value |
          |---------|-------|
          | **Server** | smtp.yourdomain.com |
          | **Port** | **465** or **587** |
          | **Encryption method** | **SSL/TLS** (465) or **STARTTLS** (587) |
          | **Outgoing server requires authentication** | ✅ Checked |
          | **Use same settings as incoming** | ✅ Checked |

          ## Click Connect
          1. Outlook will attempt to verify settings
          2. Enter your password when prompted
          3. If OAuth is supported, a browser window may open for authentication
          4. Click **Done** when setup completes

          ## Sync Settings
          After setup, right-click the account → **Account Settings** to adjust:
          - Offline email duration (1 month, 3 months, 1 year, All)
          - Download preferences (headers only vs full messages)
        INST
      },

      # Jump to verification after Outlook Windows setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Outlook Windows Setup Complete",
        "description" => "Route to verification after Windows setup",
        "branches" => [
          { "condition" => "client == 'outlook'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Outlook - macOS Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Outlook - macOS Setup",
        "description" => "Step-by-step setup for Microsoft Outlook on Mac",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up External Email in Outlook for Mac 💻

          ## Step 1: Open Outlook
          1. Open **Microsoft Outlook** from Applications
          2. Go to **Outlook** menu → **Preferences**
          3. Click **Accounts**
          4. Click the **+** button → **New Account**

          ## Step 2: Enter Email
          1. Enter your email address
          2. Click **Continue**

          ## Step 3: Choose Provider/Type
          If automatic setup fails:
          1. Click **Not Exchange?**
          2. Select **IMAP/POP**
          3. Click **Continue**

          ## Enter Server Information
          | Field | Value |
          |-------|-------|
          | **IMAP Username** | Your full email address |
          | **IMAP Password** | Your password |
          | **IMAP Server** | imap.yourdomain.com |
          | **Use SSL to connect** | ✅ Checked |
          | **IMAP Port** | **993** |
          | **SMTP Username** | Your full email address |
          | **SMTP Password** | Your password |
          | **SMTP Server** | smtp.yourdomain.com |
          | **Use SSL to connect** | ✅ Checked |
          | **SMTP Port** | **465** or **587** |

          Click **Add Account** to complete.
        INST
      },

      # Jump to verification after Outlook macOS setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Outlook macOS Setup Complete",
        "description" => "Route to verification after macOS Outlook setup",
        "branches" => [
          { "condition" => "client == 'outlook'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Outlook - iOS Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Outlook - iOS Setup",
        "description" => "Step-by-step setup for Outlook app on iPhone/iPad",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up External Email in Outlook for iOS 📱

          ## Step 1: Install/Open Outlook
          1. Download **Microsoft Outlook** from the App Store
          2. Open the app
          3. Tap **Add Account** (or gear icon → **Add Account**)

          ## Step 2: Add External Account
          1. Enter your email address
          2. Tap **Add Account**
          3. If automatic detection fails, tap **Setup Account Manually**

          ## Step 3: Select IMAP
          1. Choose **IMAP** as the account type
          2. Enter the following settings:

          | Field | Value |
          |-------|-------|
          | **IMAP Host Name** | imap.yourdomain.com |
          | **IMAP Port** | **993** |
          | **IMAP Username** | Your full email address |
          | **Security** | **SSL/TLS** |
          | **SMTP Host Name** | smtp.yourdomain.com |
          | **SMTP Port** | **465** or **587** |
          | **SMTP Security** | **SSL/TLS** or **STARTTLS** |

          ## iOS Permissions
          Allow Outlook to:
          - Send notifications
          - Access contacts
          - Refresh in background
        INST
      },

      # Jump to verification after Outlook iOS setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Outlook iOS Setup Complete",
        "description" => "Route to verification after iOS Outlook setup",
        "branches" => [
          { "condition" => "client == 'outlook'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Outlook - Android Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Outlook - Android Setup",
        "description" => "Step-by-step setup for Outlook app on Android",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Setting Up External Email in Outlook for Android 🤖

          ## Step 1: Install/Open Outlook
          1. Download **Microsoft Outlook** from Google Play Store
          2. Open the app
          3. Tap **Add Account** or the hamburger menu → gear icon → **Add Account**

          ## Step 2: Enter Email Address
          1. Type your email address
          2. Tap **Continue**
          3. If auto-detection fails, tap **Setup account manually**

          ## Step 3: Configure IMAP
          Select **IMAP** and enter:

          | Setting | Value |
          |---------|-------|
          | **Display Name** | Your name |
          | **Description** | Work Email (optional) |
          | **IMAP Host Name** | imap.yourdomain.com |
          | **IMAP Username** | Your full email address |
          | **IMAP Password** | Your password |
          | **SMTP Host Name** | smtp.yourdomain.com |
          | **SMTP Username** | Your full email address |
          | **SMTP Password** | Your password |

          ## Android Permissions
          Grant these permissions:
          - **Contacts**: For recipient suggestions
          - **Calendar**: For meeting invites
          - **Storage**: For attachments
          - **Notifications**: For email alerts
        INST
      },

      # Jump to verification after Outlook Android setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Outlook Android Setup Complete",
        "description" => "Route to verification after Android Outlook setup",
        "branches" => [
          { "condition" => "client == 'outlook'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # Outlook - Web Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Outlook - Web Setup",
        "description" => "Information about Outlook.com web interface limitations",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Outlook.com Web Interface 🌐

          ## ⚠️ Important Limitation
          **Outlook.com (web interface) does not support adding external IMAP/POP email accounts directly.**

          Outlook.com is designed for Microsoft accounts (outlook.com, hotmail.com, live.com).

          ## Alternative Solutions:

          ### Option 1: Use Outlook Desktop/Mobile App
          Download Outlook for Windows, Mac, iOS, or Android to add external IMAP accounts.

          ### Option 2: Email Forwarding
          Set up forwarding from your external email to your Outlook.com address:
          1. Log into your external email provider
          2. Configure forwarding to your @outlook.com address
          3. In Outlook.com: Settings → **Mail** → **Sync email**
          4. Add your external address as a "Send from" address

          ### Option 3: Connected Accounts (Limited)
          Some providers can be connected via:
          1. Outlook.com **Settings** ⚙️
          2. **Sync email**
          3. **Manage or choose a primary alias**

          Note: This feature has limited provider support and may not work with all IMAP servers.
        INST
      },

      # Jump to verification after Outlook Web setup
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Outlook Web Setup Complete",
        "description" => "Route to verification after Outlook Web setup",
        "branches" => [
          { "condition" => "client == 'outlook'", "path" => "Test Email Functionality" }
        ],
        "else_path" => "Test Email Functionality"
      },

      # ============================================================================
      # SECTION: TEST & VERIFICATION (Common for all paths)
      # ============================================================================
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Test Email Functionality",
        "description" => "Verify the email account is working correctly",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Testing Your Email Setup 🧪

          ## Test 1: Receiving Email
          1. Send a test email TO your configured address from another account
          2. Wait 1-2 minutes for sync
          3. Check if the email appears in your inbox
          4. If using IMAP, verify it syncs across devices

          ## Test 2: Sending Email
          1. Compose a new email FROM your configured account
          2. Send to a different email address you have access to
          3. Verify the email is received
          4. Check the "Sent" folder to confirm it was saved

          ## Test 3: Reply/Forward
          1. Reply to a received email
          2. Verify the reply thread is maintained
          3. Test forwarding an email with an attachment

          ## Test 4: Folders/Labels
          1. Check that default folders appear (Inbox, Sent, Drafts, Trash)
          2. Create a test folder/label
          3. Move an email to the test folder
          4. Verify sync across devices (if using IMAP)
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Verify Setup Success",
        "description" => "Confirm whether email setup was successful",
        "question" => "Were you able to successfully send and receive test emails?",
        "answer_type" => "yes_no",
        "variable_name" => "setup_successful"
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Setup Success Decision",
        "description" => "Branch based on setup success",
        "branches" => [
          { "condition" => "setup_successful == 'yes'", "path" => "Setup Complete - Success" }
        ],
        "else_path" => "Troubleshooting Decision"
      },

      # ============================================================================
      # SECTION: TROUBLESHOOTING PATHS
      # ============================================================================

      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Troubleshooting Decision",
        "description" => "Identify the specific issue to troubleshoot",
        "question" => "What type of error or issue are you experiencing?",
        "answer_type" => "single_choice",
        "variable_name" => "issue_type",
        "options" => [
          { "label" => "🔐 Authentication Error / Invalid Password", "value" => "auth_error" },
          { "label" => "⏱️ Connection Timeout / Server Not Found", "value" => "timeout" },
          { "label" => "📜 Certificate Error / SSL Warning", "value" => "certificate" },
          { "label" => "🔄 Sync Problems / Missing Emails", "value" => "sync" },
          { "label" => "📎 Large Attachment Issues", "value" => "attachments" },
          { "label" => "🔑 OAuth Required / Modern Auth Error", "value" => "oauth" },
          { "label" => "🔢 2FA / App Password Required", "value" => "2fa" }
        ]
      },

      # Troubleshooting Router
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Route to Troubleshooting Path",
        "description" => "Branch to the appropriate troubleshooting section based on issue type",
        "branches" => [
          { "condition" => "issue_type == 'auth_error'", "path" => "Troubleshoot Authentication Error" },
          { "condition" => "issue_type == 'timeout'", "path" => "Troubleshoot Connection Timeout" },
          { "condition" => "issue_type == 'certificate'", "path" => "Troubleshoot Certificate Error" },
          { "condition" => "issue_type == 'sync'", "path" => "Troubleshoot Sync Problems" },
          { "condition" => "issue_type == 'attachments'", "path" => "Troubleshoot Large Attachment Issues" },
          { "condition" => "issue_type == 'oauth'", "path" => "Troubleshoot OAuth / Modern Auth" },
          { "condition" => "issue_type == '2fa'", "path" => "Troubleshoot 2FA & App Passwords" }
        ],
        "else_path" => "Troubleshoot Authentication Error"
      },

      # Authentication Error Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot Authentication Error",
        "description" => "Steps to resolve authentication/password errors",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting Authentication Errors 🔐

          ## Common Causes:
          1. Incorrect password
          2. Wrong username format
          3. Account locked
          4. 2FA enabled without app password
          5. OAuth required (2026 update)

          ## Solution Steps:

          ### Step 1: Verify Password
          1. Try logging into your email provider's webmail
          2. If webmail works, the password is correct
          3. If webmail fails, reset your password

          ### Step 2: Check Username Format
          - Use your **full email address** as username
          - Example: user@company.com (not just "user")

          ### Step 3: Check Account Status
          - Log into your email provider's admin panel
          - Ensure the account is active and not locked
          - Check for any security alerts

          ### Step 4: 2FA / App Passwords
          If Two-Factor Authentication is enabled:
          1. Generate an **App Password** from your provider's security settings
          2. Use the app password instead of your regular password

          ### Step 5: OAuth / Modern Authentication (2026)
          If you see "OAuth required" or "Modern auth" errors:
          - Your provider may have disabled basic password auth
          - Try using the provider's official sign-in option
          - Check if your email client supports OAuth for your provider
        INST
      },

      # Jump to retry after auth troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After Auth Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == 'auth_error'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # Connection Timeout Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot Connection Timeout",
        "description" => "Steps to resolve connection and server issues",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting Connection Timeout ⏱️

          ## Common Causes:
          1. Incorrect server address
          2. Wrong port number
          3. Firewall blocking connection
          4. Network issues
          5. Server down

          ## Solution Steps:

          ### Step 1: Verify Server Address
          Common patterns:
          - IMAP: `imap.domain.com` or `mail.domain.com`
          - SMTP: `smtp.domain.com` or `mail.domain.com`

          Contact your email provider for exact addresses.

          ### Step 2: Verify Ports
          | Protocol | Port | Security |
          |----------|------|----------|
          | IMAP | **993** | SSL/TLS |
          | POP3 | **995** | SSL/TLS |
          | SMTP | **465** | SSL |
          | SMTP | **587** | STARTTLS |

          ### Step 3: Check Network Connection
          1. Ensure you have internet connectivity
          2. Try a different network (WiFi vs cellular)
          3. Disable VPN temporarily

          ### Step 4: Firewall Check
          - Corporate firewalls may block email ports
          - Try connecting from a different network
          - Contact IT if on corporate network

          ### Step 5: Server Status
          - Check if your email provider has a status page
          - Look for service outage announcements
          - Try again in 30 minutes if server is down
        INST
      },

      # Jump to retry after timeout troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After Timeout Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == 'timeout'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # Certificate Error Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot Certificate Error",
        "description" => "Steps to resolve SSL/TLS certificate issues",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting Certificate Errors 📜

          ## Common Causes:
          1. Expired SSL certificate on server
          2. Self-signed certificate
          3. Certificate hostname mismatch
          4. Incorrect date/time on device

          ## Solution Steps:

          ### Step 1: Check Device Date/Time
          Incorrect date/time causes certificate validation failures:
          - **iOS**: Settings → General → Date & Time → Set Automatically
          - **Android**: Settings → System → Date & time → Automatic
          - **Windows**: Settings → Time & language → Set time automatically
          - **macOS**: System Preferences → Date & Time → Set automatically

          ### Step 2: Try Different Server Address
          Some providers have multiple server addresses:
          - `mail.domain.com` vs `imap.domain.com`
          - `secure.domain.com` vs standard address

          ### Step 3: Check Security Settings
          Ensure you're using the correct security type:
          - Port 993 requires **SSL/TLS** (not STARTTLS)
          - Port 587 requires **STARTTLS** (not SSL)

          ### Step 4: Report to Provider
          If the certificate is genuinely expired:
          - Contact your email provider immediately
          - This is a server-side issue they need to fix
        INST
      },

      # Jump to retry after certificate troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After Certificate Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == 'certificate'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # Sync Issues Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot Sync Problems",
        "description" => "Steps to resolve email synchronization issues",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting Sync Problems 🔄

          ## Common Causes:
          1. POP3 vs IMAP confusion
          2. Sync settings too restrictive
          3. Storage quota exceeded
          4. Corrupted local cache

          ## Solution Steps:

          ### Step 1: Verify Protocol (IMAP vs POP)
          - **IMAP**: Syncs across all devices (recommended)
          - **POP**: Downloads to one device, may delete from server

          If using POP, emails won't appear on other devices.

          ### Step 2: Check Sync Settings
          - **iOS**: Settings → Mail → Accounts → [Account] → Mail Days to Sync
          - **Android Gmail**: Settings → [Account] → Days of mail to sync
          - **Outlook**: Account Settings → Download email for: "All" or specific period

          ### Step 3: Check Storage Quota
          1. Log into webmail
          2. Check your storage usage
          3. If over quota, delete old emails or upgrade storage

          ### Step 4: Clear Local Cache
          - **iOS**: Remove and re-add account
          - **Android**: Settings → Apps → Gmail → Clear Cache
          - **Outlook**: File → Account Settings → Data Files → remove/add
        INST
      },

      # Jump to retry after sync troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After Sync Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == 'sync'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # Large Attachment Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot Large Attachment Issues",
        "description" => "Steps to resolve attachment sending/receiving problems",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting Large Attachment Issues 📎

          ## Common Attachment Limits:
          | Provider | Max Size |
          |----------|----------|
          | Gmail | 25 MB |
          | Outlook.com | 20 MB |
          | Apple iCloud | 20 MB |
          | Most IMAP servers | 10-25 MB |

          ## Solution Steps:

          ### Step 1: Check Attachment Size
          - Ensure attachment is under the limit
          - Multiple attachments add up cumulatively

          ### Step 2: Compress Files
          - **Windows**: Right-click → Send to → Compressed folder
          - **Mac**: Right-click → Compress
          - **Mobile**: Use a file manager app to zip files

          ### Step 3: Use Cloud Sharing
          Instead of attaching large files:
          - **Google Drive**: Upload and share link
          - **OneDrive**: Upload and share link
          - **Dropbox**: Upload and share link

          ### Step 4: Split Large Files
          For files larger than any limit:
          - Use file splitting software (7-Zip, WinRAR)
          - Send in multiple emails
        INST
      },

      # Jump to retry after attachment troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After Attachment Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == 'attachments'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # OAuth Required Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot OAuth / Modern Auth",
        "description" => "Steps when OAuth or Modern Authentication is required",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting OAuth / Modern Authentication 🔑

          ## What is OAuth 2.0?
          OAuth is a secure authentication method that doesn't expose your password to the email client.

          ## 2026 Authentication Changes:
          - **Microsoft**: Basic authentication disabled for IMAP/POP/SMTP
          - **Google**: Less secure app access removed; OAuth or App Passwords required

          ## Solution Steps:

          ### For Microsoft 365 / Outlook.com:
          1. Use the built-in "Microsoft" or "Outlook" account type in your email client
          2. This automatically uses OAuth
          3. A browser window will open for authentication

          ### For Google / Gmail:
          1. Use the "Google" account type if available
          2. Or enable **2-Step Verification** and create an **App Password**:
             - Go to myaccount.google.com → Security
             - 2-Step Verification → App passwords
             - Generate a password for "Mail"
             - Use this 16-character password in your email client

          ### For Other Providers:
          1. Check if your provider supports OAuth
          2. If not, use traditional password authentication
          3. Contact your provider for modern authentication options
        INST
      },

      # Jump to retry after OAuth troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After OAuth Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == 'oauth'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # 2FA / App Password Troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Troubleshoot 2FA & App Passwords",
        "description" => "Steps to handle Two-Factor Authentication and App Passwords",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Troubleshooting 2FA & App Passwords 🔢

          ## Why App Passwords?
          When 2FA is enabled, some email clients can't prompt for the second factor. App Passwords provide a workaround.

          ## Creating App Passwords by Provider:

          ### Google/Gmail:
          1. Go to **myaccount.google.com**
          2. **Security** → **2-Step Verification** (must be ON)
          3. Scroll down to **App passwords**
          4. Select app: **Mail**, device: Your device type
          5. Click **Generate**
          6. Use the 16-character password in your email client

          ### Microsoft/Outlook.com:
          1. Go to **account.microsoft.com**
          2. **Security** → **Advanced security options**
          3. **App passwords** → **Create a new app password**
          4. Copy and use the generated password

          ### Apple iCloud:
          1. Go to **appleid.apple.com**
          2. **Sign-In and Security** → **App-Specific Passwords**
          3. Click **+** to generate
          4. Name it and copy the password

          ## Important Notes:
          - App passwords are usually 16 characters, no spaces
          - Each app should have its own app password
          - Revoke old app passwords when no longer needed
        INST
      },

      # Jump to retry after 2FA troubleshooting
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After 2FA Troubleshooting",
        "description" => "Route to retry decision",
        "branches" => [
          { "condition" => "issue_type == '2fa'", "path" => "Retry Setup" }
        ],
        "else_path" => "Retry Setup"
      },

      # ============================================================================
      # SECTION: RETRY & ESCALATION
      # ============================================================================

      # Retry Setup
      {
        "id" => SecureRandom.uuid,
        "type" => "question",
        "title" => "Retry Setup",
        "description" => "Ask if user wants to retry setup after troubleshooting",
        "question" => "After following the troubleshooting steps, would you like to retry the email setup from the beginning?",
        "answer_type" => "yes_no",
        "variable_name" => "retry_setup"
      },

      # Retry Decision
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "Retry Setup Decision",
        "description" => "Route based on retry choice",
        "branches" => [
          { "condition" => "retry_setup == 'yes'", "path" => "Select Your Email Client" }
        ],
        "else_path" => "Escalate to Technical Support"
      },

      # Escalate to Support
      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Escalate to Technical Support",
        "description" => "Information for escalating unresolved issues",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Escalating to Technical Support 📞

          ## When to Escalate:
          - Multiple troubleshooting attempts have failed
          - Error message indicates server-side issue
          - Account appears to be locked or suspended
          - Provider requires special configuration

          ## Information to Collect Before Escalating:
          1. **Email client**: {client}
          2. **Device/Platform**: {device}
          3. **Exact error message** (screenshot if possible)
          4. **Steps already tried**

          ## Support Contact Information:

          ### For Email Provider Issues:
          - Contact your email provider's technical support
          - Check their status page for outages
          - Review their knowledge base

          ### For Client Application Issues:
          - **Apple Mail**: support.apple.com
          - **Gmail**: support.google.com/mail
          - **Outlook**: support.microsoft.com

          ### Internal IT Support:
          - Contact your organization's IT helpdesk
          - Provide all collected information above
          - Request priority if email is business-critical
        INST
      },

      # Jump to completion after escalation
      {
        "id" => SecureRandom.uuid,
        "type" => "decision",
        "title" => "After Escalation",
        "description" => "Route to completion",
        "branches" => [
          { "condition" => "retry_setup == 'no'", "path" => "Document Resolution" }
        ],
        "else_path" => "Document Resolution"
      },

      # ============================================================================
      # SECTION: SUCCESS & WRAP-UP
      # ============================================================================

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Setup Complete - Success",
        "description" => "Congratulations message and next steps",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # 🎉 Email Setup Complete!

          ## Congratulations!
          Your email account has been successfully configured.

          ## What You've Accomplished:
          ✅ Email client configured: **{client}**
          ✅ Device/Platform: **{device}**
          ✅ Send and receive verified

          ## Quick Tips for Ongoing Use:

          ### Sync Settings
          - IMAP keeps emails synchronized across all devices
          - Changes made on one device appear on all others
          - Deleted emails move to trash (recoverable for 30 days typically)

          ### Best Practices
          1. **Regular cleanup**: Archive or delete old emails periodically
          2. **Folder organization**: Create folders/labels for important topics
          3. **Signature**: Set up an email signature in your client settings
          4. **Notifications**: Configure notification settings to avoid overload

          ### Security Reminders
          - Never share your password or app passwords
          - Enable 2FA on your email account if not already enabled
          - Be cautious of phishing emails
          - Regularly review account access and connected apps
        INST
      },

      {
        "id" => SecureRandom.uuid,
        "type" => "action",
        "title" => "Document Resolution",
        "description" => "Final step - documentation and wrap-up",
        "action_type" => "instructions",
        "instructions" => <<~INST
          # Documentation & Wrap-up 📝

          ## Session Summary

          This workflow has guided you through:
          1. Selecting your email client and device
          2. Configuring server settings (IMAP/SMTP)
          3. Testing email functionality
          4. Troubleshooting any issues encountered

          ## Common Server Settings Reference

          | Protocol | Port | Security |
          |----------|------|----------|
          | IMAP | **993** | SSL/TLS |
          | POP3 | **995** | SSL/TLS |
          | SMTP | **465** | SSL |
          | SMTP | **587** | STARTTLS |

          ## Need Help in the Future?

          If you encounter issues later:
          1. Re-run this workflow
          2. Check your provider's status page
          3. Review the troubleshooting sections
          4. Contact technical support with the information above

          ## Thank You!

          Thank you for using the Ultimate External Email Client Troubleshooting workflow.

          This workflow was designed to demonstrate Kizuflow's powerful features:
          - ✅ Multi-branch conditional logic
          - ✅ Variable-based personalization
          - ✅ 55+ detailed atomic steps
          - ✅ Comprehensive troubleshooting paths
          - ✅ User-friendly instructions

          ---
          *Workflow created: January 2026*
          *Research sources: Apple Support, Google Support, Microsoft Learn, official documentation*
        INST
      }
    ]

    if workflow.save
      puts "✅ Workflow created successfully!"
      puts ""
      puts "📊 Workflow Statistics:"
      puts "   Title: #{workflow.title}"
      puts "   ID: #{workflow.id}"
      puts "   Total Steps: #{workflow.steps.length}"
      puts "   Question Steps: #{workflow.steps.count { |s| s['type'] == 'question' }}"
      puts "   Decision Steps: #{workflow.steps.count { |s| s['type'] == 'decision' }}"
      puts "   Action Steps: #{workflow.steps.count { |s| s['type'] == 'action' }}"
      puts "   Variables: #{workflow.variables.join(', ')}"
      puts ""
      puts "🔗 View workflow: /workflows/#{workflow.id}"
      puts "✏️ Edit workflow: /workflows/#{workflow.id}/edit"
      puts "▶️ Run workflow: /workflows/#{workflow.id}/start"
    else
      puts "❌ Failed to create workflow:"
      workflow.errors.full_messages.each do |error|
        puts "   - #{error}"
      end
      exit 1
    end
  end
end
