# Jira CLI

List, create, edit, search, and transition Jira tickets without leaving the terminal.

![jira list output](../../docs/jira-list-output.png)

```bash
jira list                              # sprint + top 5 backlog
jira show WEAT-123                     # full details + comments
jira create "Summary" -t Task --now    # create and add to sprint
jira status WEAT-123 "In Development"  # transition status
jira search 'assignee = currentUser()' # arbitrary JQL
```

## Installation

### 1. Atlassian API Token

You will need an "API Token" for Atlassian services.

1. Navigate to [Atlassian API Token Management](https://id.atlassian.com/manage-profile/security/api-tokens)
1. Click "Create API token" (not with scopes, that's super buggy)
1. Name it something like "CLI Tools" and click "Create"
1. Copy the generated token to your profile environment variables (save to your .bashrc, for example):

```bash
export XWE_ATLASSIAN_EMAIL="you@vaisala.com"
export XWE_ATLASSIAN_API_TOKEN="your-api-token"
```

### 2. Install the CLI

First, install Click using your system package manager, to not break your global system python:

```bash
sudo pacman -S python-click # Arch Linux
sudo apt install python3-click # Debian / Ubuntu
sudo dnf install python3-click # Fedora
```

Then install the project without pulling in any packages:

```bash
pip install --no-deps --break-system-packages -e .
```

Or with [uv](https://docs.astral.sh/uv/):

```bash
uv pip install --no-deps --break-system-packages -e .
```

Verify with:

```bash
jira --help
```

### Shell completion

**Bash/Zsh** (add to `~/.bashrc` or `~/.zshrc`):

```bash
eval "$(_JIRA_COMPLETE=zsh_source jira)"
```

**Fish** (add to `~/.config/fish/completions/jira.fish`):

```fish
_JIRA_COMPLETE=fish_source jira | source
```

### First-run configuration

```bash
jira project search weather        # find your project
jira project add WEAT              # add to configured list
jira project default WEAT          # set default
jira team search "dev team"        # find your group
jira team add "dev-team-group"     # configure for assignee lookup
```
