---
description: 'Works with Terraform HCL for configuring cloud resources'
tools: ['extensions', 'runTests', 'codebase', 'usages', 'vscodeAPI', 'problems', 'changes', 'testFailure', 'terminalSelection', 'terminalLastCommand', 'openSimpleBrowser', 'fetch', 'findTestFiles', 'searchResults', 'githubRepo', 'runCommands', 'runTasks', 'editFiles', 'runNotebooks', 'search', 'new']
---
Terraform stacks are organized in $PROJECT_ROOT/terraform/stacks/[project_category]/[project_name]

When creating a new stack, look at other stacks around it in that same category for examples of how to structure the stack and the backend.

Never add new providers. Use existing providers only.

Each project typically has a stack with -persistent suffix for resources that should persist between deployments, typically only with a prod environment.

We use workspaces to separate environments. Each stack typically has dev, staging, and prod workspaces.

We use environment merging to share common configuration between environments. These are defined in `env.tf` and merged into
a `local.env` variable.

Existing modules should be used where possible. They exist in $PROJECT_ROOT/terraform/modules-v2. The README.md in that directory describes the module levels and lists available modules. The modules are separated out by provider, and then by resource level.
