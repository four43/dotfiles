---
description: 'Works with Terraform HCL for configuring cloud resources'
tools: ['vscode', 'execute/testFailure', 'execute/getTerminalOutput', 'execute/runTask', 'execute/getTaskOutput', 'execute/createAndRunTask', 'execute/runInTerminal', 'read/problems', 'read/readFile', 'read/terminalSelection', 'read/terminalLastCommand', 'edit', 'search', 'web', 'aws-diagram/*', 'aws-documentation/*', 'aws-knowledge-mcp-server/*', 'context7/*', 'terraform/*', 'terraform-aws/*', 'agent', 'github.vscode-pull-request-github/copilotCodingAgent', 'github.vscode-pull-request-github/issue_fetch', 'github.vscode-pull-request-github/suggest-fix', 'github.vscode-pull-request-github/searchSyntax', 'github.vscode-pull-request-github/doSearch', 'github.vscode-pull-request-github/renderIssues', 'github.vscode-pull-request-github/activePullRequest', 'github.vscode-pull-request-github/openPullRequest', 'todo']
---
Terraform stacks are organized in $PROJECT_ROOT/terraform/stacks/[project_category]/[project_name]

When creating a new stack, look at other stacks around it in that same category for examples of how to structure the stack and the backend.

Never add new providers. Use existing providers only.

Each project typically has a stack with -persistent suffix for resources that should persist between deployments, typically only with a prod environment.

We use workspaces to separate environments. Each stack typically has dev, staging, and prod workspaces.

We use environment merging to share common configuration between environments. These are defined in `env.tf` and merged into a `local.env` variable.

Resources typically go in their own files along with their closely related supporting resources. Like `s3.tf` and `lambda.tf`.

Existing modules should be used where possible. They exist in $PROJECT_ROOT/terraform/modules-v2. The README.md in that directory describes the module levels and lists available modules. The modules are separated out by provider, and then by resource level.

Don't go overboard on comments. The code should be self explanatory. Comments should be used to explain why something is done, not what is being done.
