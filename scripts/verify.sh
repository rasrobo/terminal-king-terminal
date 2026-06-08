#!/usr/bin/env bash
# QuestShell — Security & Functionality Verification
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
echo "║  QuestShell — Verification Suite     ║"
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
echo "▸ [1/7] Ghost blog integrity…"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/" 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "200" ] && check "Ghost blog responds with 200" pass || check "Ghost blog responds with 200 (got $HTTP_CODE)" fail

# ── 2. Unauthenticated /terminal/ is blocked ────────────────────
echo
echo "▸ [2/7] Authentication gate…"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${BASE}/terminal/" 2>/dev/null || echo "000")
[ "$HTTP_CODE" = "401" ] && check "Unauthenticated /terminal/ returns 401" pass || check "Unauthenticated /terminal/ returns 401 (got $HTTP_CODE)" fail

# ── 3. Authenticated /terminal/ works ───────────────────────────
echo
echo "▸ [3/7] Authenticated access…"
# Read credentials from .env
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
QS_USER=$(grep QS_AUTH_USER "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "")
QS_PASS=$(grep QS_AUTH_PASSWORD "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 || echo "")

if [ -n "$QS_USER" ] && [ -n "$QS_PASS" ] && [ "$QS_PASS" != "CHANGEME" ]; then
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -u "${QS_USER}:${QS_PASS}" "${BASE}/terminal/" 2>/dev/null || echo "000")
  [ "$HTTP_CODE" = "200" ] && check "Authenticated /terminal/ returns 200" pass || check "Authenticated /terminal/ returns 200 (got $HTTP_CODE)" fail
else
  echo "  ${WARN} Skipped — configure QS_AUTH_USER/QS_AUTH_PASSWORD in .env"
fi

# ── 4. QuestShell branding present ──────────────────────────────
echo
echo "▸ [4/7] Branding…"
if [ -n "$QS_USER" ] && [ -n "$QS_PASS" ] && [ "$QS_PASS" != "CHANGEME" ]; then
  BODY=$(curl -s -u "${QS_USER}:${QS_PASS}" "${BASE}/terminal/" 2>/dev/null || echo "")
  echo "$BODY" | grep -qi "QuestShell" && check "Page contains 'QuestShell' branding" pass || check "Page contains 'QuestShell' branding" fail
  echo "$BODY" | grep -qi "WebSSH2" && check "Page does NOT contain 'WebSSH2'" fail || check "Page does NOT contain 'WebSSH2'" pass
  echo "$BODY" | grep -qi "SideQuest Studios" && check "Page credits SideQuest Studios" pass || check "Page credits SideQuest Studios" fail
else
  echo "  ${WARN} Skipped — configure auth credentials"
fi

# ── 5. Security headers ─────────────────────────────────────────
echo
echo "▸ [5/7] Security headers…"
if [ -n "$QS_USER" ] && [ -n "$QS_PASS" ] && [ "$QS_PASS" != "CHANGEME" ]; then
  HEADERS=$(curl -sI -u "${QS_USER}:${QS_PASS}" "${BASE}/terminal/" 2>/dev/null || echo "")

  echo "$HEADERS" | grep -qi "X-Frame-Options:.*DENY" && check "X-Frame-Options: DENY" pass || check "X-Frame-Options: DENY" fail
  echo "$HEADERS" | grep -qi "X-Content-Type-Options:.*nosniff" && check "X-Content-Type-Options: nosniff" pass || check "X-Content-Type-Options: nosniff" fail
  echo "$HEADERS" | grep -qi "Strict-Transport-Security" && check "HSTS header present" pass || check "HSTS header present" fail
  echo "$HEADERS" | grep -qi "Content-Security-Policy" && check "CSP header present" pass || check "CSP header present" fail
  echo "$HEADERS" | grep -qi "X-Powered-By" && check "X-Powered-By hidden" fail || check "X-Powered-By hidden" pass
else
  echo "  ${WARN} Skipped — configure auth credentials"
fi

# ── 6. TLS valid ────────────────────────────────────────────────
echo
echo "▸ [6/7] TLS certificate…"
TLS_EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$TLS_EXPIRY" ]; then
  EXPIRY_EPOCH=$(date -d "$TLS_EXPIRY" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$TLS_EXPIRY" +%s 2>/dev/null)
  NOW_EPOCH=$(date +%s)
  DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))
  [ "$DAYS_LEFT" -gt 14 ] && check "TLS cert valid (${DAYS_LEFT} days left)" pass || check "TLS cert expiring soon (${DAYS_LEFT} days)" fail
else
  check "TLS cert retrievable" fail
fi

# ── 7. Container security ───────────────────────────────────────
echo
echo "▸ [7/7] Container hardening…"
docker inspect quest-shell --format '{{.HostConfig.ReadonlyRootFilesystem}}' 2>/dev/null | grep -q "true" && check "Read-only root filesystem" pass || check "Read-only root filesystem" fail
docker inspect quest-shell --format '{{.HostConfig.SecurityOpt}}' 2>/dev/null | grep -q "no-new-privileges" && check "no-new-privileges enabled" pass || check "no-new-privileges enabled" fail

# Check quest-shell-internal is truly internal
docker network inspect quest-shell-internal --format '{{.Internal}}' 2>/dev/null | grep -q "true" && check "Internal network is isolated" pass || check "Internal network is isolated" fail

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
echo "  All checks passed. QuestShell is secure. ♦"
