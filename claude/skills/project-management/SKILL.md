---
name: project-management
description: Project management via JIRA and Confluence APIs. Use when the user wants to create, search, edit, or summarize tickets, or work with Confluence pages.
---

# Project Management

Manage project work through JIRA (tickets) and Confluence (documentation).

## Sub-Skills

- [JIRA Ticket Management](jira.md) - Use the `ticket` CLI for all JIRA operations
- [Confluence API Reference](confluence.md) - Page CRUD, search, comments, spaces

## Confluence Auth

Confluence still uses direct API calls. Build an auth header:

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  "https://vaisala.atlassian.net/wiki/api/v2/..."
```

## Guidelines

- Always confirm with the user before creating, modifying, or deleting tickets/pages
- For JIRA: use `ticket` CLI commands, never raw curl
- For Confluence: use curl with the auth setup above
- Use CQL for Confluence searches
- Prefer the v2 Confluence API where available; fall back to v1 for labels and attachments
