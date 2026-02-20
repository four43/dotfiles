---
name: project-management
description: Project management via JIRA and Confluence APIs. Use when the user wants to create, search, edit, or summarize tickets, or work with Confluence pages.
---

# Project Management

Manage project work through JIRA (tickets) and Confluence (documentation) using their REST APIs.

## Environment

- **Instance**: `https://vaisala.atlassian.net`
- **Auth**: Basic auth using `$XWE_JIRA_EMAIL:$XWE_JIRA_API_TOKEN`

### Auth Setup

Build an Authorization header using base64. The `-u` curl flag can break when env vars contain special characters.

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
```

Then use on every request:

```bash
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  ...
```

## Sub-Skills

Detailed API references for each system:

- [JIRA API Reference](jira.md) - Ticket CRUD, search, transitions, sprints, comments
- [Confluence API Reference](confluence.md) - Page CRUD, search, comments, spaces

## Common Workflows

### Quick ticket creation

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"fields":{"project":{"key":"WEAT"},"issuetype":{"name":"Task"},"summary":"The ticket title"}}' \
  "https://vaisala.atlassian.net/rest/api/3/issue"
```

### Search for tickets assigned to me

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -G \
  --data-urlencode 'jql=assignee = currentUser() ORDER BY updated DESC' \
  --data-urlencode 'maxResults=10' \
  --data-urlencode 'fields=summary,status,priority' \
  "https://vaisala.atlassian.net/rest/api/3/search/jql"
```

### Find a Confluence page

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -H "Content-Type: application/json" \
  "https://vaisala.atlassian.net/wiki/api/v2/pages?title=Page+Title&space-id=12345"
```

## Guidelines

- Always confirm with the user before creating or modifying tickets/pages
- When searching, show results in a concise table format
- When creating tickets, ask for required fields if not provided (project, type, summary)
- Use JQL for JIRA searches and CQL for Confluence searches
- Prefer the v2 Confluence API where available; fall back to v1 for labels and attachments
- Parse JSON responses with `jq` for clean output
