---
name: project-management
description: Project management via JIRA and Confluence APIs. Use when the user wants to create, search, edit, or summarize tickets, or work with Confluence pages.
---

# Project Management

Manage project work through JIRA (tickets) and Confluence (documentation).

## Sub-Skills

- [JIRA Ticket Management](jira.md) - Use the `ticket` CLI for all JIRA operations
- [Confluence Page Management](confluence.md) - Use the `confluence` CLI for all Confluence operations

## Guidelines

- Always confirm with the user before creating, modifying, or deleting tickets/pages
- For JIRA: use `ticket` CLI commands, never raw curl
- For Confluence: use `confluence` CLI commands, never raw curl
- Use CQL for Confluence searches
