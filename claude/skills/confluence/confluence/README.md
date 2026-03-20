# Confluence CLI

Browse, search, create, and edit Confluence pages from the command line, as Markdown.

![confluence list output](../../docs/confluence-list-output.png)

```bash
confluence list -s DEV                   # page tree (sidebar order)
confluence show 12345678                 # page metadata + body
confluence create "Title" -s DEV         # create page
confluence search 'type = page AND text ~ "kubernetes"'
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
confluence --help
```

### Shell completion

**Bash/Zsh** (add to `~/.bashrc` or `~/.zshrc`):

```bash
eval "$(_CONFLUENCE_COMPLETE=zsh_source confluence)"
```

**Fish** (add to `~/.config/fish/completions/confluence.fish`):

```fish
_CONFLUENCE_COMPLETE=fish_source confluence | source
```

### First-run configuration

```bash
confluence space list                # see available spaces
confluence space add DEV             # add to configured list
confluence space default DEV         # set default
```
