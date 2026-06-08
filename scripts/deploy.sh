#!/usr/bin/env bash
# Terminal King Terminal — Deploy Script
# Launches/updates the Terminal King Terminal stack without affecting the Ghost blog.
#
# Usage: bash scripts/deploy.sh [--rollback]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

DOMAIN="terminalking.com"

# ── Rollback ────────────────────────────────────────────────────
if [[ "${1:-}" == "--rollback" ]]; then
  echo "⟲ Rolling back Terminal King Terminal…"
  cd "$PROJECT_DIR"
  docker compose down --remove-orphans
  echo "✓ Terminal King Terminal stopped. Ghost blog is unaffected."
  exit 0
fi

echo "╔══════════════════════════════════════╗"
echo "║  Terminal King Terminal — Deploy                 ║"
echo "╚══════════════════════════════════════╝"
echo

cd "$PROJECT_DIR"

# ── Pre-flight checks ──────────────────────────────────────────
echo "▸ Running pre-flight checks…"

# .env must exist and be filled in
if [ ! -f .env ]; then
  echo "  ✗ .env not found. Copy from .env.example and fill in:"
  echo "    cp .env.example .env && nano .env"
  exit 1
fi
if grep -q "CHANGEME" .env 2>/dev/null; then
  echo "  ✗ .env still has placeholder values. Edit it first."
  exit 1
fi
echo "  ✓ .env configured"

# nginx-proxy must be running
if ! docker ps --format '{{.Names}}' | grep -q "^nginx-proxy$"; then
  echo "  ✗ nginx-proxy container not running. Start the proxy stack first:"
  echo "    cd ~/proxy && docker compose up -d"
  exit 1
fi
echo "  ✓ nginx-proxy running"

# Network must exist
if ! docker network inspect nginx-proxy &>/dev/null; then
  echo "  ✗ 'nginx-proxy' Docker network not found."
  exit 1
fi
echo "  ✓ nginx-proxy network ready"

# Ghost blog must be healthy before we touch anything
GHOST_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" 2>/dev/null || echo "000")
if [ "$GHOST_CODE" != "200" ]; then
  echo "  ⚠ Ghost blog returned HTTP ${GHOST_CODE} — proceeding anyway"
else
  echo "  ✓ Ghost blog healthy (HTTP ${GHOST_CODE})"
fi

# ── Deploy ─────────────────────────────────────────────────────
echo
echo "▸ Deploying Terminal King Terminal…"
docker compose pull
docker compose up -d --remove-orphans

echo
echo "▸ Waiting for health check…"
HEALTHY=false
for i in $(seq 1 12); do
  STATUS=$(docker inspect terminal-king-terminal --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
  if [ "$STATUS" = "healthy" ]; then
    echo "  ✓ Terminal King Terminal is healthy"
    HEALTHY=true
    break
  fi
  if [ "$i" -eq 12 ]; then
    echo "  ⚠ Health check timeout (status: ${STATUS})"
    echo "    Check logs: docker logs terminal-king-terminal"
  fi
  sleep 5
done

# ── Reload nginx-proxy to pick up the new container ─────────────
echo
echo "▸ Reloading nginx-proxy…"
docker exec nginx-proxy nginx -s reload 2>/dev/null && echo "  ✓ nginx reloaded" || echo "  ⚠ nginx reload failed — reload manually: docker exec nginx-proxy nginx -s reload"

# ── Post-deploy verification ────────────────────────────────────
echo
echo "▸ Post-deploy checks…"

# Ghost blog still works
GHOST_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/" 2>/dev/null || echo "000")
[ "$GHOST_CODE" = "200" ] && echo "  ✓ Ghost blog still healthy (HTTP ${GHOST_CODE})" || echo "  ✗ Ghost blog broken (HTTP ${GHOST_CODE})"

# /terminal/ requires auth
TERM_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}/terminal/" 2>/dev/null || echo "000")
[ "$TERM_CODE" = "401" ] && echo "  ✓ /terminal/ requires auth (HTTP ${TERM_CODE})" || echo "  ✗ /terminal/ auth gate broken (HTTP ${TERM_CODE})"

# ── Summary ─────────────────────────────────────────────────────
echo
if [ "$HEALTHY" = true ]; then
  echo "✓ Deployment complete."
else
  echo "⚠ Deployment finished with warnings. Review output above."
fi
echo
echo "  Terminal King Terminal: https://${DOMAIN}/terminal/"
echo "  Ghost blog: https://${DOMAIN}/  (should be unaffected)"
echo
echo "  Full verify: bash scripts/verify.sh"
echo "  Rollback:    bash scripts/deploy.sh --rollback"
echo "  Logs:        docker logs -f terminal-king-terminal"
