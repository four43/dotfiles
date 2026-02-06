---
name: writing-terraform
description: Terraform HCL configuration guidelines for cloud infrastructure. Use when writing or modifying Terraform code, creating stacks, or working with AWS/cloud resources.
---

# Terraform Guidelines

## Project Structure

Stacks are organized in: `$PROJECT_ROOT/terraform/stacks/[project_category]/[project_name]`

When creating a new stack, look at existing stacks in the same category for examples.

## Workspaces and Environments

- Workspaces separate environments: `dev`, `staging`, `prod`
- Environment merging shares common configuration between environments
- Defined in `env.tf` and merged into `local.env` variable

## Persistent Resources

- Stacks with `-persistent` suffix contain resources that persist between deployments
- Typically only have a `prod` environment

## File Organization

- Resources go in their own files with closely related supporting resources
- Examples: `s3.tf`, `lambda.tf`, `iam.tf`

## Modules

- Modules exist in `$PROJECT_ROOT/terraform/modules-v2`
- See the README.md in that directory for module levels and available modules
- Modules are separated by provider, then by resource level
- Use existing modules where possible

## Providers

Never add new providers. Use existing providers only.

## Comments

- Keep comments minimal
- Code should be self-explanatory
- Comments explain WHY, not WHAT
