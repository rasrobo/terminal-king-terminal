#!/usr/bin/env bash
# Terminal King Terminal — Security & Functionality Verification
# Run after deployment to validate all security controls.
#
# Usage: bash scripts/verify.sh

set -euo pipefail

DOMAIN="terminalking.com"
BASE="https://${DOMAIN}"
PASS="\033[32m✓\033[0m"
FAIL="\033[31m✗\033[0m"
WARN="\033[33m⚠\033[0m"

echo "╔══════════════════════════════════════╗"
echo "║  Terminal King Terminal — Verification Suite     ║"
echo "╚══════════════════════════════════════╝"
echo

PASS_COUNT=0
FAIL_COUNT=0

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "pass" ]; then
    echo -e "  ${PASS} ${desc}"
    ((PASS_COUNT++))
  else
    echo -e "  ${FAIL} ${desc}"
    ((FAIL_COUNT++))
  fi
}

# ── 1. Ghost blog still works ───────────────────────────────────
echo "▸ [1/8] Ghost blog integrity…"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/" 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "200" ] && check "Ghost blog responds with 200" pass || check "Ghost blog responds with 200 (got $HTTP_CODE)" fail

# ── 2. Landing page at /terminal/ is public ─────────────────────
echo
echo "▸ [2/8] Landing page…"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/terminal/" 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "200" ] && check "Landing page /terminal/ is public (200)" pass || check "Landing page /terminal/ is public (got $HTTP_CODE)" fail

LANDING=$(curl -s "${BASE}/terminal/" 2>/dev/null || echo "")
echo "$LANDING" | grep -qi "Terminal King Terminal" && check "Landing page has project branding" pass || check "Landing page has project branding" fail
echo "$LANDING" | grep -qi "github.com/rasrobo/terminal-king-terminal" && check "Landing page links to GitHub" pass || check "Landing page links to GitHub" fail
echo "$LANDING" | grep -qi 'href="/terminal/app/"' && check "Landing page links to /terminal/app/" pass || check "Landing page links to /terminal/app/" fail

# ── 3. Unauthenticated /terminal/app/ is blocked ────────────────
echo
echo "▸ [3/8] Authentication gate…"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/terminal/app/" 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "401" ] && check "Unauthenticated /terminal/app/ returns 401" pass || check "Unauthenticated /terminal/app/ returns 401 (got $HTTP_CODE)" fail

# ── 4. Authenticated /terminal/app/ works ───────────────────────
echo
echo "▸ [4/8] Authenticated access…"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TKT_USER=$(grep TKT_AUTH_USER "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "")
TKT_PASS=$(grep TKT_AUTH_PASSWORD "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "")

if [ -n "$TKT_USER" ] && [ -n "$TKT_PASS" ] && [ "$TKT_PASS" != "CHANGEME" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${TKT_USER}:${TKT_PASS}" "${BASE}/terminal/app/" 2>/dev/null || echo "000")
  [ "$HTTP_CODE" = "200" ] && check "Authenticated /terminal/app/ returns 200" pass || check "Authenticated /terminal/app/ returns 200 (got $HTTP_CODE)" fail
else
  echo "  ${WARN} Skipped — configure TKT_AUTH_USER/TKT_AUTH_PASSWORD in .env"
fi

# ── 5. Terminal King Terminal branding present ──────────────────
echo
echo "▸ [5/8] Branding…"
if [ -n "$TKT_USER" ] && [ -n "$TKT_PASS" ] && [ "$TKT_PASS" != "CHANGEME" ]; then
  BODY=$(curl -s -u "${TKT_USER}:${TKT_PASS}" "${BASE}/terminal/app/" 2>/dev/null || echo "")
  echo "$BODY" | grep -qi "Terminal King Terminal" && check "Page contains 'Terminal King Terminal' branding" pass || check "Page contains 'Terminal King Terminal' branding" fail
  echo "$BODY" | grep -qi "WebSSH2" && check "Page does NOT contain 'WebSSH2'" fail || check "Page does NOT contain 'WebSSH2'" pass
else
  echo "  ${WARN} Skipped — configure auth credentials"
fi

# ── 6. Security headers ─────────────────────────────────────────
echo
echo "▸ [6/8] Security headers…"
if [ -n "$TKT_USER" ] && [ -n "$TKT_PASS" ] && [ "$TKT_PASS" != "CHANGEME" ]; then
  HEADERS=$(curl -sI -u "${TKT_USER}:${TKT_PASS}" "${BASE}/terminal/app/" 2>/dev/null || echo "")

  echo "$HEADERS" | grep -qi "X-Frame-Options:.*DENY" && check "X-Frame-Options: DENY" pass || check "X-Frame-Options: DENY" fail
  echo "$HEADERS" | grep -qi "X-Content-Type-Options:.*nosniff" && check "X-Content-Type-Options: nosniff" pass || check "X-Content-Type-Options: nosniff" fail
  echo "$HEADERS" | grep -qi "Strict-Transport-Security" && check "HSTS header present" pass || check "HSTS header present" fail
  echo "$HEADERS" | grep -qi "Content-Security-Policy" && check "CSP header present" pass || check "CSP header present" fail
  echo "$HEADERS" | grep -qi "X-Powered-By" && check "X-Powered-By hidden" fail || check "X-Powered-By hidden" pass
else
  echo "  ${WARN} Skipped — configure auth credentials"
fi

# ── 7. TLS valid ────────────────────────────────────────────────
echo
echo "▸ [7/8] TLS certificate…"
TLS_EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$TLS_EXPIRY" ]; then
  EXPIRY_EPOCH=$(date -d "$TLS_EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$TLS_EXPIRY" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
  [ "$DAYS_LEFT" -gt 14 ] && check "TLS cert valid (${DAYS_LEFT} days left)" pass || check "TLS cert expiring soon (${DAYS_LEFT} days)" fail
else
  check "TLS cert retrievable" fail
fi

# ── 8. Container security ───────────────────────────────────────
echo
echo "▸ [8/8] Container hardening…"
docker inspect terminal-king-terminal --format '{{.HostConfig.ReadonlyRootFilesystem}}' 2>/dev/null | grep -q "true" && check "Read-only root filesystem" pass || check "Read-only root filesystem" fail
docker inspect terminal-king-terminal --format '{{.HostConfig.SecurityOpt}}' 2>/dev/null | grep -q "no-new-privileges" && check "no-new-privileges enabled" pass || check "no-new-privileges enabled" fail
docker network inspect terminal-king-terminal-internal --format '{{.Internal}}' 2>/dev/null | grep -q "true" && check "Internal network is isolated" pass || check "Internal network is isolated" fail

# ── Summary ─────────────────────────────────────────────────────
echo
echo "═══════════════════════════════════════"
echo "  Results: ${PASS_COUNT} passed, ${FAIL_COUNT} failed"
echo "═══════════════════════════════════════"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo
  echo "  Some checks failed. Review the output above."
  exit 1
fi

echo
echo "  All checks passed. Terminal King Terminal is secure. ♦"
