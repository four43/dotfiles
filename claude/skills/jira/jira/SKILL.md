---
name: jira
description: Jira ticket management via the `jira` CLI. Use when the user wants to create, search, edit, transition, or summarize Jira tickets.
---

# JIRA Ticket Management

Use the `jira` CLI for all JIRA operations. Never use raw curl or API calls.

## Quick Reference

```shell
jira list                                  # sprint + top 5 backlog
jira list --all                            # include Done
jira list --backlog                        # backlog only
jira list --sprint current                 # current sprint only
jira show WEAT-123                         # full details + comments
jira search 'JQL query'                    # arbitrary JQL search
jira create "Summary" [options]            # create ticket
jira edit WEAT-123                         # edit summary + description (stdin or $EDITOR)
jira status WEAT-123 "In Development"      # transition status
jira comment WEAT-123 "Comment text"       # add comment (arg, stdin, or $EDITOR)
jira assign WEAT-123 "Jane Smith"          # reassign
jira assign WEAT-123 --none                # unassign
jira move WEAT-123 current                 # move to active sprint
jira move WEAT-123 backlog                 # move to backlog
jira move WEAT-123 "Sprint 42"             # move to named sprint
jira link WEAT-123 blocks WEAT-456         # link: this blocks that
jira link WEAT-123 blocked-by WEAT-456     # link: this is blocked by that
jira link WEAT-123 relates-to WEAT-456     # link: relates to
jira unlink WEAT-123 WEAT-456              # remove link between issues
jira delete WEAT-123                       # delete (prompts for confirmation)
jira sprints                               # list sprints
jira project list                          # configured projects
jira team show                             # team members
```

## Create Options

```shell
jira create "Summary" \
  -d "Description text" \
  -p WEAT \
  -t Task \
  -c ComponentName \
  -a "Jane Smith" \
  -l tech-debt \
  --priority High \
  --parent WEAT-100 \
  --now
```

- `-d` / `--description` - description text
- `-p` / `--project` - project key (default: last used)
- `-t` / `--type` - issue type (default: Task)
- `-c` / `--component` - component (repeatable)
- `-a` / `--assignee` - assignee name (default: me)
- `-l` / `--label` - label (repeatable)
- `--priority` - High, Medium, Low
- `--parent` - parent issue key (creates subtask)
- `--now` - add to active sprint

## Linking Issues

```bash
jira link WEAT-123 blocks WEAT-456         # WEAT-123 blocks WEAT-456
jira link WEAT-123 blocked-by WEAT-456     # WEAT-123 is blocked by WEAT-456
jira link WEAT-123 relates-to WEAT-456     # bidirectional "relates to"
jira unlink WEAT-123 WEAT-456             # remove all links between the two
```

- Link types: `blocks`, `blocked-by`, `relates-to`
- `jira show` displays links when present
- `jira unlink` removes all links between two issues (regardless of type)

## Editing and Commenting via stdin

For non-interactive use, pipe content to `edit` and `comment`:

```bash
echo "Updated summary
──── description ────
New description here" | jira edit WEAT-123

echo "Comment text" | jira comment WEAT-123
```

## Useful JQL Queries

```shell
jira search 'project = WEAT AND sprint in openSprints()'
jira search 'project = WEAT AND labels = "tech-debt" ORDER BY updated DESC'
jira search 'project = WEAT AND text ~ "search term"'
jira search 'project = WEAT AND status changed AFTER -7d'
jira search 'project = WEAT AND created >= -1w ORDER BY created DESC'
jira search 'assignee = currentUser() AND statusCategory not in (Done)'
```

## Setup Commands

```shell
jira project search weather              # find projects
jira project add WEAT                     # add to configured list
jira project default WEAT                 # set default
jira team search "dev team"               # find groups
jira team add "dev-team-group"            # configure for assignee lookup
jira team show                            # list team members
```

## Guidelines

- Always confirm with the user before creating, modifying, or deleting tickets
- Use `jira search` with JQL for any query not covered by `jira list`
- Browse URL: `https://vaisala.atlassian.net/browse/{KEY}`
