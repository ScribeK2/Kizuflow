# Kizuflow

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
- **Template Library**: Browse and use pre-built workflow templates
  - Post-onboarding checklists
  - Troubleshooting decision trees
  - Client training flows
- **Simulation Mode**: Run workflows with inputs and see execution paths in real-time
- **Export Capabilities**: Export workflows as JSON or PDF for documentation
- **Workflow Sharing**: Public workflows can be shared with other users for collaborative editing

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
   git clone <repository-url>
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
3. **Create a workflow**: Start from scratch, use a template from the library, or import from JSON/CSV/YAML/Markdown
4. **Build your workflow**: Add steps using the drag-and-drop interface
   - Add questions to collect user input
   - Add decisions to create branching logic
   - Add actions to define workflow steps
5. **Collaborate in real-time**: Multiple users can edit the same workflow simultaneously with live updates
6. **Test your workflow**: Use simulation mode to run workflows with test inputs
7. **Export workflows**: Export completed workflows as JSON or PDF
8. **Share workflows**: Make workflows public to allow other users to view and edit them

### Workflow Building

Workflows consist of three types of steps:

- **Question Steps**: Collect user input that can be stored as variables
- **Decision Steps**: Branch workflows based on conditions using variables from question steps
- **Action Steps**: Define actions to be performed at specific points in the workflow

Steps can be reordered using drag-and-drop, and decision steps support multiple branches with conditions.

### Workflow Import

Import workflows from multiple file formats:

- **JSON**: Native Kizuflow export format with full step definitions
- **CSV**: Spreadsheet format with columns for Type, Title, Question, Answer Type, etc.
- **YAML**: Structured configuration format with hierarchical key-value pairs
- **Markdown**: Documentation format with step headers and field definitions

Partial imports are supported - incomplete steps will be marked for your attention and can be completed on the edit page. Step references in markdown files are automatically resolved (e.g., "Step 3" references are mapped to actual step titles).

### Real-Time Collaboration

Multiple users can edit the same workflow simultaneously:

- See presence indicators showing who else is currently editing
- Changes are synchronized in real-time across all connected clients
- Step updates, additions, removals, and reordering happen instantly
- Metadata changes (title, description) are broadcast to all editors

### Templates

Browse the template library to find pre-built workflows for common scenarios:
- Post-onboarding checklists
- Troubleshooting decision trees
- Client training flows

Templates can be used as-is or customized for your specific needs.

### Simulations

Run simulations to test workflows before deploying them:
- Provide input values for question steps
- Follow the execution path through decision branches
- View the complete execution log
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
- Controllers: `app/controllers/` - Workflows, Templates, Simulations, Dashboard, Admin
- Views: `app/views/` - Server-rendered ERB templates
- JavaScript: `app/javascript/` - Stimulus controllers for interactivity
- Channels: `app/channels/` - Action Cable channels for real-time features
- Services: `app/services/` - Workflow parsers for import functionality
- Styles: `app/assets/stylesheets/` - Tailwind CSS configuration

### Key Files

- `app/models/workflow.rb` - Core workflow model with step validation and authorization
- `app/models/user.rb` - User model with role-based methods
- `app/controllers/workflows_controller.rb` - Workflow CRUD operations and import
- `app/channels/workflow_channel.rb` - Action Cable channel for real-time collaboration
- `app/services/workflow_parsers/` - Parsers for JSON, CSV, YAML, and Markdown imports
- `app/javascript/controllers/workflow_collaboration_controller.js` - Real-time collaboration logic
- `app/javascript/controllers/workflow_builder_controller.js` - Drag-and-drop workflow builder
- `config/routes.rb` - Application routes including admin namespace
- `db/schema.rb` - Database schema

## Deployment

The application is configured for deployment with Kamal. Configuration details can be found in `config/deploy.yml`.

### Production Considerations

- Set `RAILS_MASTER_KEY` environment variable
- Configure PostgreSQL database credentials
- Set up Active Storage for file uploads
- Configure Action Cable for WebSocket connections (required for real-time collaboration)
- Set `SECRET_KEY_BASE` for session encryption
- Configure Redis or another adapter for Action Cable pub/sub
- Set up initial admin user via seed data or database migration

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
