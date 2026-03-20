---
name: git-activity
description: Summarize recent git commits across project directories. Use when the user wants to review what they've worked on recently, prepare standup notes, or compare activity against Jira tickets.
---

# Git Activity Summary

Scan git repositories for recent commits by the user to produce a work activity summary.

## CLI Tool

The `git-activity` script lives in this skill directory. Run it with Bash.

```shell
# Basic: scan all repos under a directory for commits in past 2 days
git-activity ~/projects

# Custom lookback period
git-activity --days 5 ~/projects

# Fetch remotes first (picks up commits pushed from other machines)
git-activity --fetch ~/projects

# Specific author
git-activity --author "Seth Miller" --days 3 ~/projects
```

### Output Format

Markdown-formatted list grouped by repository:

```
## repo-name

- abc1234 2026-03-19 Add feature X
- def5678 2026-03-18 Fix bug in Y

## other-repo

- 1a2b3c4 2026-03-19 Refactor Z module
```

## Combining with Jira

After generating the activity summary, compare it against the user's Jira tickets to identify:

1. **Commits without tickets** - work done that isn't tracked
2. **Tickets without commits** - assigned work with no recent progress
3. **Ticket status mismatches** - e.g. ticket is "To Do" but commits exist (should be "In Development")

Workflow:
```shell
# 1. Get recent commits
git-activity --fetch ~/projects

# 2. Get assigned Jira tickets
jira list

# 3. Cross-reference and suggest updates
```

## Guidelines

- Default to 2 days lookback for daily standups
- Use `--fetch` when the user may have pushed from another machine
- Merge commits are excluded from output (--no-merges)
- Uses `--all` to scan both local and remote-tracking branches
