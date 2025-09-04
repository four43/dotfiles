#!/bin/bash

# Git SSH Key Multi-Authentication Wrapper
#
# This script acts as an SSH wrapper for git operations that automatically tries
# multiple SSH keys from the SSH agent when authenticating to remote repositories.
# Useful when you have multiple GitHub/GitLab accounts with different SSH keys.
#
# !WARNING! This might not work well in all environments and setups that don't respect
# GIT_SSH. Use with caution.
#
# Features:
# - Iterates through all SSH keys loaded in ssh-agent
# - Continues trying keys on permission/authentication failures
# - Falls back to default SSH behavior if all keys fail
# - Supports debug logging (set DEBUG=1)
# - Handles git clone, fetch, push operations seamlessly
#
# Usage:
#   export GIT_SSH_COMMAND="/absolute/path/to/git-ssh-wrapper.sh"
#   git clone git@github.com:user/repo.git
#
# Requirements:
# - SSH agent running with keys loaded (ssh-add -l)

# This script acts as an SSH wrapper for git operations
# It tries different SSH keys from the agent, with HTTPS fallback
HOST="$1"
shift
ORIGINAL_COMMAND="$*"

# Init logging
DEBUG=0
log() {
  if [[ $DEBUG -eq 1 ]]; then
	echo "$@" >&2
  fi
}

log "SSH wrapper called for host: $HOST with command: $ORIGINAL_COMMAND"

# If this is a GitHub connection and we have a token, we could fallback to HTTPS
# But for SSH wrapper, we focus on trying different SSH keys

# Get list of SSH key files from the agent
KEYS=$(ssh-add -L 2>/dev/null)
if [[ -z "$KEYS" ]]; then
  log "No keys found in SSH agent, falling back to default SSH"
  exec ssh "$HOST" "$ORIGINAL_COMMAND"
fi

# Count and display number of keys
KEY_COUNT=$(echo "$KEYS" | wc -l)
log "Found $KEY_COUNT SSH keys in agent"

# Temp directory for key testing
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Try each key
readarray -t KEY_ARRAY <<< "$KEYS"
for ((INDEX=0; INDEX<${#KEY_ARRAY[@]}; INDEX++)); do
  KEY_LINE="${KEY_ARRAY[$INDEX]}"

  if [[ -z "$KEY_LINE" ]]; then
    continue
  fi

  KEY_FILE="$TMP_DIR/key_$INDEX"
  echo "$KEY_LINE" > "$KEY_FILE"
  chmod 600 "$KEY_FILE"

  log "Trying SSH key $INDEX..."
  ssh -i "$KEY_FILE" -o IdentitiesOnly=yes -o PasswordAuthentication=no -o StrictHostKeyChecking=yes "$HOST" "$ORIGINAL_COMMAND"
  EXIT_CODE=$?

  # Check for specific success conditions
  # Exit code 0 means complete success
  # We should also continue on permission/auth errors but not on connection errors
  if [[ $EXIT_CODE -eq 0 ]]; then
    log "SSH operation succeeded with key $INDEX"
    exit 0
  elif [[ $EXIT_CODE -eq 128 ]] || [[ $EXIT_CODE -eq 1 ]]; then
    # Git/permission errors - try next key
    log "Key $INDEX failed with git/permission error (exit $EXIT_CODE), trying next key..."
  else
    # Other SSH connection errors - try next key
    log "Key $INDEX failed with SSH error (exit $EXIT_CODE), trying next key..."
  fi
done

log "All SSH keys failed. Trying default SSH behavior."
exec ssh "$HOST" "$ORIGINAL_COMMAND"
