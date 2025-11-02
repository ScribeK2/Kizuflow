# Kizuflow

<img width="1560" height="1117" alt="image" src="https://github.com/user-attachments/assets/6be51bf9-8719-4ba0-9207-12e9a2c0f7f7" />

A straightforward, no-nonsense workflow creator for call/chat centers to build and simulate post-onboarding training and client troubleshooting flows. Built as a simple Ruby on Rails monolith that focuses on core functionality without unnecessary complexity.

## Overview

Kizuflow enables call/chat centers to create custom workflows with drag-and-drop step management, run simulations to test workflows, and export results. The application is designed for practical use by non-technical users who need quick, customizable workflows for training new clients post-onboarding and troubleshooting common issues.

## Features

### Core Functionality

- **User Authentication**: Secure email/password signup and login via Devise
- **Workflow Builder**: Create custom workflows with drag-and-drop step management
  - Question steps: Collect user input with variable tracking
  - Decision steps: Branch workflows based on conditions
  - Action steps: Define actions to be performed
- **Template Library**: Browse and use pre-built workflow templates
  - Post-onboarding checklists
  - Troubleshooting decision trees
  - Client training flows
- **Simulation Mode**: Run workflows with inputs and see execution paths in real-time
- **Export Capabilities**: Export workflows as JSON or PDF for documentation
- **Real-time Updates**: Action Cable integration for live workflow editing

### Technical Highlights

- Server-rendered views for fast page loads
- Hotwire (Turbo + Stimulus) for seamless interactivity
- Drag-and-drop workflow step reordering
- Rich text editing with Action Text
- Active Storage for file attachments

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

Workflows consist of three types of steps:

- **Question Steps**: Collect user input that can be stored as variables
- **Decision Steps**: Branch workflows based on conditions using variables from question steps
- **Action Steps**: Define actions to be performed at specific points in the workflow

Steps can be reordered using drag-and-drop, and decision steps support multiple branches with conditions.

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
