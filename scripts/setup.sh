#!/usr/bin/env bash
# QuestShell — Initial Setup Script
# Run ONCE on the server after cloning the repo.
#
# Usage: bash scripts/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔══════════════════════════════════════╗"
echo "║  QuestShell — Setup                  ║"
echo "║  SideQuest Studios                   ║"
echo "╚══════════════════════════════════════╝"
echo

# ── 1. Check prerequisites ──────────────────────────────────────
echo "[1/6] Checking prerequisites…"

for cmd in docker openssl htpasswd; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "  ✗ Missing: $cmd — please install it first"
    exit 1
  fi
  echo "  ✓ $cmd"
done

# Check nginx-proxy network exists
if ! docker network inspect nginx-proxy &>/dev/null; then
  echo "  ✗ Docker network 'nginx-proxy' not found."
  echo "    Make sure the existing nginx-proxy stack is running."
  exit 1
fi
echo "  ✓ nginx-proxy network"

# ── 2. Generate .env from example ───────────────────────────────
echo
echo "[2/6] Setting up .env…"

if [ ! -f "$PROJECT_DIR/.env" ]; then
  cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
  echo "  ⚠ Created .env from example — EDIT IT with your real values!"
else
  echo "  ✓ .env already exists (not overwriting)"
fi

# ── 3. Generate htpasswd ────────────────────────────────────────
echo
echo "[3/6] Setting up HTTP Basic Auth…"

HTPASSWD_DIR="/var/www/terminalking.com/quest-shell"
HTPASSWD_FILE="$HTPASSWD_DIR/.htpasswd"

sudo mkdir -p "$HTPASSWD_DIR"

if [ ! -f "$HTPASSWD_FILE" ]; then
  echo "  Creating htpasswd file…"
  echo -n "  Enter QuestShell admin username: "
  read -r QS_USER
  htpasswd -cB "$HTPASSWD_FILE" "$QS_USER"
  echo "  ✓ Created $HTPASSWD_FILE"
else
  echo "  ✓ htpasswd already exists at $HTPASSWD_FILE"
  echo "  To add users: htpasswd $HTPASSWD_FILE username"
fi

# Secure the htpasswd file
sudo chmod 640 "$HTPASSWD_FILE"
sudo chown root:www-data "$HTPASSWD_FILE" 2>/dev/null || true

# ── 4. Link vhost config + htpasswd into nginx-proxy ─────────────
echo
echo "[4/6] Linking nginx vhost config and htpasswd…"

# The nginx-proxy container uses Docker named volumes for vhost.d and certs.
# We need to place our files where nginx-proxy will read them.
#
# Method: Find the volume mount paths on the host and copy files there.
# The nginx-proxy container mounts:
#   - vhost volume → /etc/nginx/vhost.d
#   - certs volume → /etc/nginx/certs
#
# We add our htpasswd to the vhost volume since it's per-domain config.

# Find the vhost volume name
VHOST_VOLUME=$(docker inspect nginx-proxy --format '{{range .Mounts}}{{if eq .Destination "/etc/nginx/vhost.d"}}{{.Name}}{{end}}{{end}}' 2>/dev/null || echo "")

if [ -n "$VHOST_VOLUME" ]; then
  VHOST_DIR="/var/lib/docker/vhost.d"
  # Try to find the actual volume path
  VHOST_HOSTPATH=$(docker volume inspect "$VHOST_VOLUME" --format '{{.Mountpoint}}' 2>/dev/null || echo "")

  if [ -n "$VHOST_HOSTPATH" ] && [ -d "$VHOST_HOSTPATH" ]; then
    sudo cp "$PROJECT_DIR/nginx/vhost-terminalking.conf" "$VHOST_HOSTPATH/terminalking.com"
    sudo cp "$HTPASSWD_FILE" "$VHOST_HOSTPATH/htpasswd/terminalking.htpasswd" 2>/dev/null || {
      sudo mkdir -p "$VHOST_HOSTPATH/htpasswd"
      sudo cp "$HTPASSWD_FILE" "$VHOST_HOSTPATH/htpasswd/terminalking.htpasswd"
    }
    echo "  ✓ Vhost config and htpasswd linked into nginx-proxy volume"
  else
    echo "  ⚠ Cannot find volume mountpoint. Manual step required:"
    echo "    Copy nginx/vhost-terminalking.conf to the nginx-proxy vhost.d volume as 'terminalking.com'"
    echo "    Copy .htpasswd to the same volume under 'htpasswd/terminalking.htpasswd'"
  fi
else
  echo "  ⚠ Cannot detect nginx-proxy volumes. Manual step required."
  echo "    See README.md section 'Manual nginx-proxy Setup'"
fi

# ── 5. Pull the WebSSH2 image ───────────────────────────────────
echo
echo "[5/6] Pulling WebSSH2 image…"
docker pull billchurch/webssh2:latest
echo "  ✓ Image pulled"

# ── 6. Pre-flight summary ───────────────────────────────────────
echo
echo "[6/6] Pre-flight checks…"
echo
echo "  Before running 'bash scripts/deploy.sh':"
echo "    1. Edit .env with your SSH target settings"
echo "    2. Ensure terminalking.com DNS points to this server"
echo "    3. Verify nginx-proxy is running: docker ps | grep nginx-proxy"
echo "    4. Test Ghost blog: curl -I https://terminalking.com/"
echo
echo "  Setup complete. ♦"
