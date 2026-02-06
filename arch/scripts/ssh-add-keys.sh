#!/bin/bash
# Add SSH keys on login (optional - can also add keys on-demand)
# This will prompt via ksshaskpass, which can remember passwords in KWallet

# Small delay to ensure ssh-agent is ready
sleep 1

# Add your SSH keys
ssh-add ~/.ssh/id_rsa ~/.ssh/id_rsa_vaisala 2>/dev/null
