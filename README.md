# Kizuflow

<img width="1560" height="1117" alt="Kizuflow Dashboard" src="https://github.com/user-attachments/assets/6be51bf9-8719-4ba0-9207-12e9a2c0f7f7" />

A workflow builder for call/chat centers to create, simulate, and manage training and troubleshooting flows. Built as a Ruby on Rails monolith using Hotwire for interactivity.

## Features

- **Workflow Builder** - Drag-and-drop interface with four step types: questions, decisions, actions, and checkpoints
- **Simulation Mode** - Test workflows step-by-step with input tracking and execution paths
- **Real-Time Collaboration** - Multi-user editing with presence indicators via Action Cable
- **Template Library** - Pre-built workflows for onboarding, troubleshooting, and training
- **Import/Export** - Import from JSON, CSV, YAML, Markdown; export to JSON or PDF
- **Hierarchical Groups** - Organize workflows into nested groups with role-based access control
- **Role-Based Access** - Administrator, Editor, and User roles with granular permissions

## Tech Stack

- Ruby on Rails 8.0
- Hotwire (Turbo + Stimulus)
- Tailwind CSS
- SQLite (development) / PostgreSQL (production)
- Devise authentication
- Action Cable for WebSockets

## Prerequisites

- Ruby 3.3.0+
- Bundler
- SQLite3 (development) or PostgreSQL (production)

No Node.js required - uses Rails' #nobuild approach with importmap-rails and tailwindcss-rails standalone CLI.

## Installation

```bash
# Clone and install dependencies
git clone https://github.com/ScribeK2/Kizuflow
cd Kizuflow
bundle install

# Setup database
rails db:create db:migrate db:seed

# Start development server (includes Tailwind watch)
bin/dev
```

Visit `http://localhost:3000` to access the application.

## Usage

1. **Sign up** with email and password
2. **Create a workflow** from scratch or use a template
3. **Add steps** using the drag-and-drop builder
4. **Test** with simulation mode
5. **Export** as JSON or PDF

## Running Tests

```bash
bin/rails test
```

## Deployment

Configured for deployment with Kamal. See `config/deploy.yml` for details.

Required environment variables:
- `RAILS_MASTER_KEY`
- `SECRET_KEY_BASE`
- PostgreSQL credentials

## Contributing

Contributions welcome. Please follow Rails conventions, add tests for new features, and ensure all tests pass before submitting.

## License

Open source. See [LICENSE](LICENSE) for details.
