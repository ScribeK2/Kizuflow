# AGENTS.md

This file provides guidance to AI coding agents working with TurboFlows.

## What is TurboFlows?
A straightforward workflow creator for call/chat centers to build, simulate, and manage post-onboarding training + client troubleshooting flows with drag-and-drop simplicity.

- Six step types: Question, Action, Sub-Flow, Message, Escalate, Resolve
- Linear (collapsible cards) + Graph editing modes (dagre + leader-line visuals)
- Scenario Mode: interactive step-by-step simulation with variable interpolation {{var}}, sub-flow recursion, safety limits
- Real-time collaboration via Action Cable (WorkflowChannel presence)
- Hierarchical Groups (up to 5 levels) + Folders + drag-and-drop organization
- Template library + import/export (JSON/CSV/YAML/MD → JSON/PDF via Prawn)
- No Node.js: pure Hotwire (Turbo + Stimulus), importmap + Propshaft, vanilla CSS (@layer + OKLCH tokens)
- Rails 8.1, Devise auth (roles: Administrator / Editor / User), optimistic locking (lock_version)

## Development Commands

**Setup (one-time)**
```bash
git clone https://github.com/ScribeK2/TurboFlows
cd TurboFlows
bundle install
rails db:create db:migrate db:seed    # creates DB + seeds initial data (if any)
```

**Run locally**
```bash
bin/dev             # starts Puma + Action Cable → http://localhost:3000
```

**Login**

Sign up with any email/password (Devise). Use seeded/admin account if present in `db/seeds.rb` (check file for credentials).

**Testing (Minitest)**
```bash
bin/rails test                                              # full suite
bin/rails test test/models/workflow_test.rb                 # single file
bin/rails test test/models/workflow_test.rb:42              # single test by line
bin/rails test -v                                           # verbose output
```

**Database & Utils**
```bash
rails db:reset        # drop/create/migrate/seed
rails console
```

**Deployment**

Kamal: `kamal deploy` (see `config/deploy.yml`). Required env: `RAILS_MASTER_KEY`, `SECRET_KEY_BASE`, PostgreSQL creds.

## Architecture Overview

**Core Domain Models**

- `Workflow` — container with versions (`workflow_version.rb`), autosave, optimistic locking (`lock_version`)
- `Step` — STI base class (`app/models/step.rb`); subclasses in `app/models/steps/` (QuestionStep, ActionStep, SubFlowStep, etc.)
- `Transition` — branching logic between steps
- `Scenario` — simulation runner (executes steps, resolves `{{variables}}`, spawns child scenarios for sub-flows, enforces limits)
- `Group` / `Folder` — hierarchical org (recursive membership, cascade permissions)
- `User` — Devise model with roles (Administrator / Editor / User)
- `Template` / `StepTemplate` — reusable patterns

## Real-Time & Collaboration

- WorkflowChannel (Action Cable) — presence (who's editing), live updates
- In-memory cable in dev; Redis in production
- Optimistic locking prevents save conflicts

## Editing Modes

- **Linear:** collapsible cards, inline creation
- **Graph:** visual nodes/connections (vendored dagre/leader-line)

## Other Highlights

- Rich text: Action Text + Lexxy (Lexical editor)
- Client-side search: Fuse.js
- Drag-and-drop: SortableJS
- No multi-tenancy (single install/org), but strong group-based access
- Background jobs: Active Job (expandable to Solid Queue)
- Security: Rack::Attack, Bullet (N+1), Brakeman

## Coding Style
@STYLE.md

## Tools
Chrome MCP (for UI/system testing). Point agent to running app at `http://localhost:3000` (after `bin/dev`). Allows browser control (click, type, screenshot, inspect) — ideal for testing Graph Mode, Scenario simulation, wizard flows, drag-and-drop.

## Deployment Notes

- Branch: `main`
- Tool: Kamal + Puma + PostgreSQL
- Pre-deploy: RuboCop + full test suite
