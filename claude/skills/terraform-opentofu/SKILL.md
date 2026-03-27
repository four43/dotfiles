---
name: terraform-opentofu
description: Terraform and OpenTofu HCL configuration guidelines for cloud infrastructure. Use when writing or modifying Terraform/OpenTofu code, creating stacks, or working with AWS/cloud resources.
---

# Terraform / OpenTofu Guidelines

## Verify Changes with Documentation

Before writing or suggesting resource configurations, **always search the Terraform Registry
documentation** to verify:

- Resource and data source argument names and types
- Required vs optional arguments
- Default values and behavior
- Attribute references available for outputs
- Provider version constraints and compatibility

Use the available MCP tools to search and fetch documentation:

- `mcp__terraform__search_providers` — find providers by name
- `mcp__terraform__get_provider_details` — get provider docs, resource lists, data sources
- `mcp__terraform__get_provider_capabilities` — see available resources, data sources, functions, and guides
- `mcp__terraform__get_latest_provider_version` — check current version
- `mcp__terraform__search_modules` — find reusable modules
- `mcp__terraform__get_module_details` — get module inputs, outputs, and usage
- `mcp__terraform__get_latest_module_version` — check current module version
- `mcp__terraform-aws__SearchAwsProviderDocs` — search AWS provider resource docs
- `mcp__terraform-aws__SearchAwsccProviderDocs` — search AWSCC provider resource docs

When in doubt, search first. Do not guess argument names or assume resource behavior.

## Provider Documentation Quick Reference

### AWS Provider

- Registry: `hashicorp/aws`
- Search for resources: use `mcp__terraform-aws__SearchAwsProviderDocs` with the resource name
  (e.g., "s3_bucket", "lambda_function", "iam_role")
- Common resource prefixes: `aws_s3_`, `aws_lambda_`, `aws_iam_`, `aws_ec2_`, `aws_ecs_`,
  `aws_rds_`, `aws_cloudwatch_`, `aws_route53_`, `aws_vpc_`, `aws_sqs_`, `aws_sns_`

### AWSCC Provider

- Registry: `hashicorp/awscc`
- Auto-generated from AWS CloudFormation schemas
- Search: use `mcp__terraform-aws__SearchAwsccProviderDocs`
- Prefer `aws` provider when both cover a resource; use `awscc` for newer AWS services not yet
  in the `aws` provider

### Other Common Providers

Search using `mcp__terraform__search_providers` for:
- `hashicorp/azurerm` — Azure
- `hashicorp/google` — Google Cloud
- `hashicorp/kubernetes` — Kubernetes
- `hashicorp/helm` — Helm charts
- `hashicorp/tls` — TLS certificates
- `hashicorp/random` — Random values
- `hashicorp/null` — Null resources / provisioners
- `hashicorp/local` — Local file operations
- `hashicorp/archive` — ZIP/archive creation

## OpenTofu Compatibility

OpenTofu is a fork of Terraform and uses the same HCL syntax. Key differences:

- OpenTofu uses `tofu` CLI instead of `terraform`
- Provider registry defaults to `registry.opentofu.org` but supports Terraform registry providers
- State encryption is a native OpenTofu feature (not available in Terraform)
- Early variable/locals evaluation is supported in OpenTofu
- For provider docs, the Terraform Registry documentation applies to both

When writing code that needs to work with both:
- Avoid Terraform-specific features added after the fork (post v1.6)
- Avoid OpenTofu-specific features like state encryption if targeting both
- Use `required_providers` blocks with explicit source addresses

## Architecture Verification

When designing or reviewing infrastructure architecture:

1. **Search for existing modules** before building from individual resources
2. **Check provider capabilities** to understand what resources are available
3. **Verify resource relationships** — check docs for required dependencies and ordering
4. **Review security implications** — check for encryption, access control, and network
   isolation options on each resource

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
