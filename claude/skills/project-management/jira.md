# JIRA API Reference

REST API v3 at `https://vaisala.atlassian.net/rest/api/3/`
Agile API at `https://vaisala.atlassian.net/rest/agile/1.0/`

Auth: Build a base64 header — do NOT use curl's `-u` flag (breaks with special chars in env vars):

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
# Then on every request:
-H "Authorization: Basic ${AUTH}" -H "Content-Type: application/json"
```

## Issues

### Get issue

```
GET /rest/api/3/issue/{issueIdOrKey}
```

Query params:
- `fields` - comma-separated field names (e.g. `summary,status,assignee,description`)
- `expand` - expand fields (e.g. `renderedFields,transitions,changelog`)

### Create issue

```
POST /rest/api/3/issue
```

```json
{
  "fields": {
    "project": { "key": "WEAT" },
    "issuetype": { "name": "Task" },
    "summary": "Ticket title",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [{ "type": "text", "text": "Description text" }]
        }
      ]
    },
    "assignee": { "accountId": "<accountId>" },
    "priority": { "name": "Medium" },
    "labels": ["label1"],
    "components": [{ "name": "ComponentName" }]
  }
}
```

Response includes `key` (e.g. `WEAT-123`) and `id`.

Note: Description uses Atlassian Document Format (ADF), not plain text.

### Edit issue

```
PUT /rest/api/3/issue/{issueIdOrKey}
```

Send only the fields to update:

```json
{
  "fields": {
    "summary": "Updated title",
    "labels": ["new-label"]
  }
}
```

### Delete issue

```
DELETE /rest/api/3/issue/{issueIdOrKey}
```

Query params:
- `deleteSubtasks` - `true` to also delete subtasks

### Assign issue

```
PUT /rest/api/3/issue/{issueIdOrKey}/assignee
```

```json
{ "accountId": "<accountId>" }
```

Use `{ "accountId": null }` to unassign.

## Search (JQL)

### Search with JQL

**IMPORTANT**: The old `POST /rest/api/3/search` endpoint has been removed.
Use the new endpoint with **GET** and query parameters:

```
GET /rest/api/3/search/jql?jql={jql}&maxResults={n}&fields={fields}
```

Use curl's `-G` and `--data-urlencode` to properly encode parameters:

```bash
AUTH=$(printf '%s:%s' "${XWE_JIRA_EMAIL}" "${XWE_JIRA_API_TOKEN}" | base64 -w 0)
curl -s \
  -H "Authorization: Basic ${AUTH}" \
  -G \
  --data-urlencode 'jql=project = WEAT AND status = "In Progress" ORDER BY updated DESC' \
  --data-urlencode 'maxResults=25' \
  --data-urlencode 'startAt=0' \
  --data-urlencode 'fields=summary,status,assignee,priority,updated' \
  "https://vaisala.atlassian.net/rest/api/3/search/jql"
```

**JQL gotcha**: The `!=` operator gets mangled during URL encoding. Use `not in (Value)` instead:
- BAD: `statusCategory != Done`
- GOOD: `statusCategory not in (Done)`

Useful JQL queries:
- `assignee = currentUser() ORDER BY updated DESC` - My tickets
- `assignee = currentUser() AND statusCategory not in (Done) ORDER BY updated DESC` - My open tickets
- `project = WEAT AND sprint in openSprints()` - Current sprint
- `project = WEAT AND status changed AFTER -7d` - Recently updated
- `project = WEAT AND text ~ "search term"` - Full text search
- `project = WEAT AND created >= -1w ORDER BY created DESC` - Created this week
- `project = WEAT AND status = Done AND resolved >= -1w` - Recently completed

Response: `{ "issues": [{ "key": "WEAT-1", "fields": { ... } }] }`

### Issue picker (autocomplete)

```
GET /rest/api/3/issue/picker?query=search+term&currentProjectId=WEAT
```

## Transitions (Status Changes)

### Get available transitions

```
GET /rest/api/3/issue/{issueIdOrKey}/transitions
```

Returns list of valid transitions from the current status.

### Perform transition

```
POST /rest/api/3/issue/{issueIdOrKey}/transitions
```

```json
{
  "transition": { "id": "31" },
  "fields": {},
  "update": {
    "comment": [
      {
        "add": {
          "body": {
            "type": "doc",
            "version": 1,
            "content": [
              {
                "type": "paragraph",
                "content": [{ "type": "text", "text": "Moving to In Progress" }]
              }
            ]
          }
        }
      }
    ]
  }
}
```

Workflow: Get transitions first to find the `id`, then POST with that id.

## Comments

### List comments

```
GET /rest/api/3/issue/{issueIdOrKey}/comment
```

Query params:
- `startAt`, `maxResults` - pagination
- `orderBy` - `created` or `-created`
- `expand` - `renderedBody` for HTML

### Add comment

```
POST /rest/api/3/issue/{issueIdOrKey}/comment
```

```json
{
  "body": {
    "type": "doc",
    "version": 1,
    "content": [
      {
        "type": "paragraph",
        "content": [{ "type": "text", "text": "Comment text here" }]
      }
    ]
  }
}
```

### Update comment

```
PUT /rest/api/3/issue/{issueIdOrKey}/comment/{commentId}
```

Same body format as add comment.

### Delete comment

```
DELETE /rest/api/3/issue/{issueIdOrKey}/comment/{commentId}
```

## Projects

### List projects

```
GET /rest/api/3/project/search
```

Query params:
- `query` - filter by name
- `maxResults`, `startAt` - pagination
- `expand` - `description,lead,url`

### Get project

```
GET /rest/api/3/project/{projectIdOrKey}
```

### List project components

```
GET /rest/api/3/project/{projectIdOrKey}/components
```

### List project versions

```
GET /rest/api/3/project/{projectIdOrKey}/versions
```

## Users

### Get current user

```
GET /rest/api/3/myself
```

Returns `accountId`, `displayName`, `emailAddress`.

### Search users

```
GET /rest/api/3/user/search?query=name
```

### Find assignable users

```
GET /rest/api/3/user/assignable/search?project=WEAT&query=name
```

## Worklogs

### Add worklog

```
POST /rest/api/3/issue/{issueIdOrKey}/worklog
```

```json
{
  "timeSpentSeconds": 3600,
  "comment": {
    "type": "doc",
    "version": 1,
    "content": [
      {
        "type": "paragraph",
        "content": [{ "type": "text", "text": "Worked on implementation" }]
      }
    ]
  },
  "started": "2024-01-15T09:00:00.000+0000"
}
```

## Agile (Boards & Sprints)

### List boards

```
GET /rest/agile/1.0/board?projectKeyOrId=WEAT
```

### Get board sprints

```
GET /rest/agile/1.0/board/{boardId}/sprint?state=active
```

States: `future`, `active`, `closed`.

### Get sprint issues

```
GET /rest/agile/1.0/sprint/{sprintId}/issue
```

### Move issues to sprint

```
POST /rest/agile/1.0/sprint/{sprintId}/issue
```

```json
{ "issues": ["WEAT-123", "WEAT-456"] }
```

Returns `204 No Content` on success.

### Rank issues

```
PUT /rest/agile/1.0/issue/rank
```

```json
{
  "issues": ["WEAT-123"],
  "rankBeforeIssue": "WEAT-100"
}
```

## Atlassian Document Format (ADF)

JIRA v3 uses ADF for rich text fields (description, comments). Key node types:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    { "type": "paragraph", "content": [{ "type": "text", "text": "Plain text" }] },
    { "type": "heading", "attrs": { "level": 2 }, "content": [{ "type": "text", "text": "Heading" }] },
    { "type": "bulletList", "content": [
      { "type": "listItem", "content": [
        { "type": "paragraph", "content": [{ "type": "text", "text": "Item 1" }] }
      ]}
    ]},
    { "type": "codeBlock", "attrs": { "language": "python" }, "content": [
      { "type": "text", "text": "print('hello')" }
    ]},
    { "type": "blockquote", "content": [
      { "type": "paragraph", "content": [{ "type": "text", "text": "Quoted text" }] }
    ]}
  ]
}
```

Text marks for inline formatting:
- `{ "type": "text", "text": "bold", "marks": [{ "type": "strong" }] }`
- `{ "type": "text", "text": "italic", "marks": [{ "type": "em" }] }`
- `{ "type": "text", "text": "code", "marks": [{ "type": "code" }] }`
- `{ "type": "text", "text": "link text", "marks": [{ "type": "link", "attrs": { "href": "https://..." } }] }`

## Links

- Browse issue: `https://vaisala.atlassian.net/browse/{issueKey}`
- Board: `https://vaisala.atlassian.net/jira/software/projects/{projectKey}/boards/{boardId}`
