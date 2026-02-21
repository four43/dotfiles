# Confluence Page Management

Use the `confluence` CLI for all Confluence operations. Never use raw curl or API calls.

## Quick Reference

```
confluence show 12345678                     # page metadata + body
confluence search 'CQL query'               # CQL search (v1 endpoint)
confluence list -s DEV                       # page tree (sidebar order)
confluence list -s DEV --sort modified       # flat list, most recently modified first
confluence children 12345678                 # list child pages
confluence create "Title" -s DEV             # create page (body from stdin/$EDITOR)
confluence edit 12345678                     # edit title + body (stdin/$EDITOR)
confluence comment 12345678 "Comment text"   # add footer comment (arg, stdin, or $EDITOR)
confluence label list 12345678               # list labels
confluence label add 12345678 l1 l2          # add labels
confluence label remove 12345678 old-label   # remove label
confluence space list                        # list spaces
confluence space add DEV                     # add to configured list
confluence space default DEV                 # set default space
```

## Creating and Editing via stdin

For non-interactive use, pipe content to `create`, `edit`, and `comment`:

```bash
echo "Page content here" | confluence create "New Page Title" -s DEV

echo "Updated Title
──── content ────
Updated body content" | confluence edit 12345678

echo "Comment text" | confluence comment 12345678
```

## Useful CQL Queries

```
confluence search 'type = page AND space = "DEV" AND title ~ "deploy"'
confluence search 'type = page AND text ~ "kubernetes"'
confluence search 'type = page AND label = "runbook"'
confluence search 'type = page AND space = "DEV" AND lastModified > now("-7d")'
confluence search 'type = page AND ancestor = 12345678'
```

## Setup Commands

```
confluence space list                        # see available spaces
confluence space add DEV                     # add to configured list
confluence space default DEV                 # set default
```

## Guidelines

- Always confirm with the user before creating, modifying, or deleting pages
- Use `confluence search` with CQL for flexible queries
- Use `confluence list` for browsing pages in a space
- View page URL: `https://vaisala.atlassian.net/wiki/pages/{pageId}`
- Space home URL: `https://vaisala.atlassian.net/wiki/spaces/{spaceKey}`
