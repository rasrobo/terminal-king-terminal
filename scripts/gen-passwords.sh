#!/usr/bin/env bash
# Terminal King Terminal — Password Generator
# Generates secure random passwords and htpasswd entries.

set -euo pipefail

echo "Terminal King Terminal — Password Generator"
echo

echo "# Random hex password (for .env):"
openssl rand -hex 32
echo

echo "# htpasswd entry (Interactive):"
echo -n "  Username: "
read -r USERNAME
htpasswd -nBC 14 "$USERNAME"
echo
echo "# Copy the output line above into your .htpasswd file."
