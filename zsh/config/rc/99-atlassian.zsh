#!/bin/zsh

# Activate click shell completion for the ticket CLI
eval "$(_JIRA_COMPLETE=zsh_source jira)"
eval "$(_CONFLUENCE_COMPLETE=zsh_source confluence)"
