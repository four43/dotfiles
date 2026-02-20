# JIRA Ticket Management

Use the `ticket` CLI for all JIRA operations. Never use raw curl or API calls.

## Quick Reference

```
ticket list                                  # sprint + top 5 backlog
ticket list --all                            # include Done
ticket list --backlog                        # backlog only
ticket list --sprint current                 # current sprint only
ticket show WEAT-123                         # full details + comments
ticket search 'JQL query'                    # arbitrary JQL search
ticket create "Summary" [options]            # create ticket
ticket edit WEAT-123                         # edit summary + description (stdin or $EDITOR)
ticket status WEAT-123 "In Development"      # transition status
ticket comment WEAT-123 "Comment text"       # add comment (arg, stdin, or $EDITOR)
ticket assign WEAT-123 "Jane Smith"          # reassign
ticket assign WEAT-123 --none               # unassign
ticket move WEAT-123 current                 # move to active sprint
ticket move WEAT-123 backlog                 # move to backlog
ticket move WEAT-123 "Sprint 42"             # move to named sprint
ticket delete WEAT-123                       # delete (prompts for confirmation)
ticket sprints                               # list sprints
ticket project list                          # configured projects
ticket team show                             # team members
```

## Create Options

```
ticket create "Summary" \
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

## Editing and Commenting via stdin

For non-interactive use, pipe content to `edit` and `comment`:

```bash
echo "Updated summary
──── description ────
New description here" | ticket edit WEAT-123

echo "Comment text" | ticket comment WEAT-123
```

## Useful JQL Queries

```
ticket search 'project = WEAT AND sprint in openSprints()'
ticket search 'project = WEAT AND labels = "tech-debt" ORDER BY updated DESC'
ticket search 'project = WEAT AND text ~ "search term"'
ticket search 'project = WEAT AND status changed AFTER -7d'
ticket search 'project = WEAT AND created >= -1w ORDER BY created DESC'
ticket search 'assignee = currentUser() AND statusCategory not in (Done)'
```

## Setup Commands

```
ticket project search weather              # find projects
ticket project add WEAT                     # add to configured list
ticket project default WEAT                 # set default
ticket team search "dev team"               # find groups
ticket team add "dev-team-group"            # configure for assignee lookup
ticket team show                            # list team members
```

## Guidelines

- Always confirm with the user before creating, modifying, or deleting tickets
- Use `ticket search` with JQL for any query not covered by `ticket list`
- Browse URL: `https://vaisala.atlassian.net/browse/{KEY}`
