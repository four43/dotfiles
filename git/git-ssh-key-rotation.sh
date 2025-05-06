#!/bin/bash
set -euo pipefail

# Tries each SSH key in the agent until one works
# Usage: git-ssh-key-rotation.sh <ssh command>
# Set GIT_SSH=[this script] in your environment

# Set log file location
LOG_FILE="$HOME/.cache/git-ssh/log/log.txt"
mkdir -p "$(dirname "$LOG_FILE")"
truncate -s 0 "$LOG_FILE"

# Function to log messages
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Start the log entry
log "==== Starting new SSH attempt ===="
log "Script arguments: $*"

# Get identities from SSH agent
SSH_PUB_KEYS=($(ssh-add -L | awk '{print $2}'))
if [ ${#SSH_PUB_KEYS[@]} -eq 0 ]; then
  log "No SSH keys found in the agent."
  exit 1
fi

# Get SSH Key Paths
KEY_PATHS=()
for PUB_KEY in "${SSH_PUB_KEYS[@]}"; do
  set +eo pipefail
  KEY_PATH=$(grep -lr "$PUB_KEY" ~/.ssh/ 2>/dev/null | grep '\.pub$' | sed 's/.pub$//')
  set -eo pipefail
  if [ -n "$KEY_PATH" ]; then
    KEY_PATHS+=("$KEY_PATH")
    log "Added key path: $KEY_PATH"
  else
    log "Key $PUB_KEY not found in ~/.ssh/**id_*.pub"
  fi
done

log "Found ${#KEY_PATHS[@]} keys to try"

log "Checking keys..."
for KEY_PATH in "${KEY_PATHS[@]}"; do
  log "Trying key: $KEY_PATH"
  set +e
  if ssh -i "${KEY_PATH}" "$@"; then
      log "Success with key: $KEY_PATH"
      exit 0
  fi
done
