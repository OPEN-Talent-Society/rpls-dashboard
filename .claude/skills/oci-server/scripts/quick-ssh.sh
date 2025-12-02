#!/bin/bash
# Quick SSH to OCI Docker host
# Usage: ./quick-ssh.sh [command]
#
# Examples:
#   ./quick-ssh.sh                    # Interactive shell
#   ./quick-ssh.sh "docker ps"        # Run command
#   ./quick-ssh.sh "cat /srv/wiki/.env"  # View file

SSH_KEY="$HOME/Downloads/ssh-key-2025-10-17.key"
SSH_HOST="ubuntu@163.192.41.116"

if [ -z "$1" ]; then
    # Interactive session
    echo "Connecting to OCI Docker Host (163.192.41.116)..."
    ssh -i "$SSH_KEY" "$SSH_HOST"
else
    # Run command
    ssh -i "$SSH_KEY" "$SSH_HOST" "$@"
fi
