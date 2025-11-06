# Kizuflow

<img width="1560" height="1117" alt="Kizuflow Dashboard" src="https://github.com/user-attachments/assets/6be51bf9-8719-4ba0-9207-12e9a2c0f7f7" />

A straightforward, no-nonsense workflow creator for call/chat centers to build and simulate post-onboarding training and client troubleshooting flows. Built as a simple Ruby on Rails monolith that focuses on core functionality without unnecessary complexity.

## Overview

Kizuflow enables call/chat centers to create custom workflows with drag-and-drop step management, run simulations to test workflows, and export results. The application is designed for practical use by non-technical users who need quick, customizable workflows for training new clients post-onboarding and troubleshooting common issues.

## Features

### Core Functionality

- **User Authentication**: Secure email/password signup and login via Devise
- **User Roles and Permissions**: Role-based access control with Administrator, Editor, and User roles
  - Administrators have full system access including user management
  - Editors can create and edit workflows, including public workflows
  - Users can create and manage their own workflows
- **Workflow Builder**: Create custom workflows with drag-and-drop step management
  - Question steps: Collect user input with variable tracking
  - Decision steps: Branch workflows based on conditions
  - Action steps: Define actions to be performed
  - Checkpoint steps: Create resolution points where users can mark issues as resolved or continue workflow
- **Real-Time Collaboration**: Multi-user live workflow editing with Action Cable
  - See other users editing in real-time
  - Presence indicators show active editors
  - Automatic synchronization of changes across all connected clients
- **Workflow Import System**: Import workflows from multiple file formats
  - JSON import (native Kizuflow export format)
  - CSV import with column mapping
  - YAML import with hierarchical structure support
  - Markdown import with automatic step reference resolution
  - Partial import support with visual indicators for incomplete steps
- **Unified Workflows Section**: Browse all accessible workflows in one place
  - Unified "Workflows" section showing public workflows and user-assigned workflows
  - Real-time search with fuzzy matching on titles and descriptions
  - Clean, minimalist interface with permission-aware filtering
- **Simplified Workflow Execution**: Easy workflow start with dedicated landing pages
  - Prominent "Start" buttons on workflow cards and listings
  - Dedicated start page with workflow overview and clear call-to-action
  - Streamlined flow for end-users without technical details
- **Workflow Control**: Stop workflows at any point
  - "Stop Workflow" button available during execution
  - Tracks stopping point for analytics and metrics
  - Visual indicators show stopped status with details
- **Checkpoint Steps**: Resolution points for early workflow completion
  - Add checkpoint steps to mark resolution opportunities
  - Users can mark issues as resolved (completing workflow) or continue
  - Optional notes field for resolution tracking
  - Analytics tracking for resolution rates
- **Template Library**: Browse and use pre-built workflow templates
  - Post-onboarding checklists
  - Troubleshooting decision trees
  - Client training flows
- **Simulation Mode**: Run workflows with inputs and see execution paths in real-time
  - Step-by-step execution with progress tracking
  - Resolution options at checkpoint steps
  - Stop workflow at any point
- **Export Capabilities**: Export workflows as JSON or PDF for documentation
- **Workflow Sharing**: Public workflows can be shared with other users for collaborative editing
- **Workflow Grouping**: Organize workflows into hierarchical groups and subgroups
  - Create groups and nested subgroups (e.g., Customer Experience > Phone Support)
  - Assign workflows to one or more groups during creation or editing
  - Filter workflows by group using the collapsible sidebar tree
  - User-level group access control: assign users to specific groups
  - Admins see all groups; users only see groups they're assigned to
  - Backward compatible: existing workflows default to "Uncategorized" group

### Technical Highlights

- Server-rendered views for fast page loads
- Hotwire (Turbo + Stimulus) for seamless interactivity
- Drag-and-drop workflow step reordering
- Rich text editing with Action Text
- Active Storage for file attachments
- Action Cable WebSocket integration for real-time features
- Role-based authorization system

## Tech Stack

- **Framework**: Ruby on Rails 8.0
- **Frontend**: Hotwire (Turbo + Stimulus)
- **Styling**: Tailwind CSS
- **Database**: SQLite (development) / PostgreSQL (production)
- **Authentication**: Devise
- **PDF Generation**: Prawn
- **Drag-and-Drop**: Sortable.js
- **Rich Text**: Action Text (Trix)
- **Real-time**: Action Cable

## Prerequisites

Before you begin, ensure you have the following installed:

- Ruby 3.3.0 or higher
- Rails 8.0
- Bundler
- SQLite3 (for development)
- PostgreSQL (for production)
- Node.js (for asset compilation)

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ScribeK2/Kizuflow
   cd Kizuflow
   ```

2. **Install Ruby dependencies:**
   ```bash
   bundle install
   ```

3. **Set up the database:**
   ```bash
   rails db:create
   rails db:migrate
   rails db:seed
   ```

   The seed file includes sample templates for post-onboarding, troubleshooting, and training workflows.

4. **Compile assets:**
   ```bash
   bin/rails tailwindcss:build
   ```

5. **Start the Rails server:**
   ```bash
   rails server
   ```

6. **Visit the application:**
   Open your browser and navigate to `http://localhost:3000`

## Usage

### Getting Started

1. **Create an account**: Sign up with your email address and password
2. **Access the dashboard**: View all your workflows and templates from the main dashboard
3. **Create a workflow**: Start from scratch or use a template from the library
4. **Build your workflow**: Add steps using the drag-and-drop interface
   - Add questions to collect user input
   - Add decisions to create branching logic
   - Add actions to define workflow steps
5. **Test your workflow**: Use simulation mode to run workflows with test inputs
6. **Export workflows**: Export completed workflows as JSON or PDF

### Workflow Building

Workflows consist of four types of steps:

- **Question Steps**: Collect user input that can be stored as variables
- **Decision Steps**: Branch workflows based on conditions using variables from question steps
- **Action Steps**: Define actions to be performed at specific points in the workflow
- **Checkpoint Steps**: Create resolution points where users can mark issues as resolved (completing the workflow early) or continue to the next step

Steps can be reordered using drag-and-drop, and decision steps support multiple branches with conditions. Checkpoint steps allow for early workflow completion when issues are resolved, improving efficiency for common resolution scenarios.

### Templates

Browse the template library to find pre-built workflows for common scenarios:
- Post-onboarding checklists
- Troubleshooting decision trees
- Client training flows

Templates can be used as-is or customized for your specific needs.

### Workflow Grouping

Kizuflow supports hierarchical organization of workflows using Groups and Subgroups. This feature improves navigation, scalability, and access control as your organization grows.

#### Creating and Managing Groups

**Admin Access Required**: Only administrators can create and manage groups.

1. **Navigate to Group Management**: Go to Admin > Manage Groups
2. **Create a Group**: Click "New Group" and provide:
   - Name (required, must be unique within the same parent)
   - Description (optional, shown in tooltips)
   - Parent Group (optional, for creating subgroups)
   - Position (optional, for ordering)
3. **Create Subgroups**: When creating a group, select a parent group to create a nested hierarchy
4. **Edit Groups**: Click the edit icon next to any group to modify its details
5. **Delete Groups**: Groups can only be deleted if they have no subgroups or workflows

#### Group Hierarchy Rules

- **Maximum Depth**: Groups can be nested up to 5 levels deep
- **Unique Names**: Group names must be unique within the same parent (siblings can't have the same name)
- **Circular References**: The system prevents circular references (e.g., A → B → A)
- **Deletion Protection**: Groups with subgroups or workflows cannot be deleted

#### Assigning Workflows to Groups

When creating or editing a workflow:

1. **Select Groups**: Use the "Group Assignment" dropdown to select one or more groups
2. **Primary Group**: The first selected group becomes the primary group
3. **Multiple Groups**: Workflows can belong to multiple groups
4. **Default Assignment**: If no groups are selected, workflows are automatically assigned to "Uncategorized"

#### Group-Based Navigation

The Workflows page features a collapsible sidebar showing your accessible groups:

- **All Workflows**: View all workflows you have access to (default view)
- **Group Tree**: Browse groups hierarchically with expand/collapse controls
- **Filtering**: Click a group to filter workflows to that group and its subgroups
- **Breadcrumbs**: When viewing a group, breadcrumbs show the full path (e.g., Customer Experience > Phone Support)
- **Search**: Search works within the selected group context

#### User-Group Access Control

**Assigning Groups to Users** (Admin Only):

1. Go to Admin > Manage Users
2. Click the "Groups" button next to a user
3. Select the groups the user should have access to
4. Users assigned to a parent group automatically see workflows in child groups
5. Use "Bulk Assign Groups" to assign groups to multiple users at once

**Access Rules**:

- **Admins**: See all groups and workflows regardless of assignment
- **Editors**: See workflows in their assigned groups + their own workflows + public workflows
- **Users**: See workflows in their assigned groups + public workflows
- **Uncategorized Group**: All users can see the "Uncategorized" group (for backward compatibility)

#### Backward Compatibility

- Existing workflows without group assignments are automatically assigned to "Uncategorized"
- New workflows default to "Uncategorized" if no groups are selected
- Workflows without groups remain accessible to all users
- Public workflows are always accessible regardless of group assignment

### Simulations

Run simulations to test workflows before deploying them:
- Provide input values for question steps
- Follow the execution path through decision branches
- Resolve checkpoints when issues are addressed (completing workflow early) or continue
- Stop workflow execution at any point if needed
- View the complete execution log with resolution status
- Identify potential issues or improvements

## Development

### Running Tests

The application uses RSpec for testing:

```bash
bundle exec rspec
```

### Code Structure

The application follows Rails conventions:
- Models: `app/models/` - Workflow, Template, Simulation, User
- Controllers: `app/controllers/` - Workflows, Templates, Simulations, Dashboard
- Views: `app/views/` - Server-rendered ERB templates
- JavaScript: `app/javascript/` - Stimulus controllers for interactivity
- Styles: `app/assets/stylesheets/` - Tailwind CSS configuration

### Key Files

- `app/models/workflow.rb` - Core workflow model with step validation
- `app/controllers/workflows_controller.rb` - Workflow CRUD operations
- `app/javascript/controllers/` - Stimulus controllers for frontend interactivity
- `config/routes.rb` - Application routes
- `db/schema.rb` - Database schema

## Deployment

The application is configured for deployment with Kamal. Configuration details can be found in `config/deploy.yml`.

### Production Considerations

- Set `RAILS_MASTER_KEY` environment variable
- Configure PostgreSQL database credentials
- Set up Active Storage for file uploads
- Configure Action Cable for WebSocket connections
- Set `SECRET_KEY_BASE` for session encryption

## Contributing

Contributions are welcome! When contributing:

1. Follow Rails conventions and style guidelines
2. Add tests for new features
3. Update documentation as needed
4. Ensure all tests pass before submitting

## License

This project is open source. See the LICENSE file for details.

## Support

For issues, questions, or contributions, please use the GitHub issue tracker.
