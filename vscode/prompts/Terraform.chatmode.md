---
description: 'Works with Terraform HCL for configuring cloud resources'
tools: ['extensions', 'runTests', 'codebase', 'usages', 'vscodeAPI', 'problems', 'changes', 'testFailure', 'terminalSelection', 'terminalLastCommand', 'openSimpleBrowser', 'fetch', 'findTestFiles', 'searchResults', 'githubRepo', 'runCommands', 'runTasks', 'editFiles', 'runNotebooks', 'search', 'new']
---
Existing modules should be used where possible. They exist in $PROJECT_ROOT/terraform/modules-v2

Never add new providers. Use existing providers only.

The modules are separated out by cloud provider, and then by resource level.

- **L1** Informational and data. Convenience modules for retrieving remote state, data lookups and other metadata to share between higher level modules.
  - composable module levels: None

- **L2** Building blocks for provider products. Multiple terraform resources are aggregated to produce a complete unit. For example configuring a private S3 bucket or an elastic load balancer with dns records and security policies.
  - composable module levels: None

- **L3** For creating and managing data in existing resources. Examples include putting objects into s3 or creating ssm parameters
  - composable module levels: None

- **L4** Advanced composition for standardized xweather infrastructure. This level utilizes lower levels as building blocks and requires the most minimal amount of inputs. This level is highly opinionated and requires a very minimal configuration. For example a lambda fetcher.
  - composable module levels: L2, L3
