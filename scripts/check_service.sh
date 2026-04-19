#!/usr/bin/env bash
# check_service.sh — Verify V2C Project service health on Raspberry Pi
# Usage: bash scripts/check_service.sh [host] [port]
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-3000}"
URL="http://${HOST}:${PORT}/health"

PASS="\033[1;32m✅\033[0m"
FAIL="\033[1;31m❌\033[0m"
INFO="\033[1;34mℹ️\033[0m"

echo -e "${INFO}  Checking V2C Project service at ${URL}"
echo "────────────────────────────────────────"

# ── 1. systemd unit ──────────────────────────────────────────────────────────
if systemctl is-active --quiet v2c-server 2>/dev/null; then
    echo -e "${PASS} v2c-server.service is running"
else
    echo -e "${FAIL} v2c-server.service is NOT running"
    echo "    Try: sudo systemctl start v2c-server"
fi

if systemctl is-active --quiet v2c-report.timer 2>/dev/null; then
    echo -e "${PASS} v2c-report.timer is active"
else
    echo -e "${FAIL} v2c-report.timer is NOT active"
    echo "    Try: sudo systemctl start v2c-report.timer"
fi

# ── 2. HTTP healthcheck ──────────────────────────────────────────────────────
echo ""
if ! command -v curl &>/dev/null; then
    echo -e "${FAIL} curl not found — install with: sudo apt install curl"
    exit 1
fi

HTTP_CODE=$(curl -s -o /tmp/v2c_health.json -w "%{http_code}" --max-time 5 "$URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${PASS} HTTP /health → 200 OK"
    if command -v python3 &>/dev/null; then
        STATUS=$(python3 -c "import json,sys; d=json.load(open('/tmp/v2c_health.json')); print(d.get('status','?'))" 2>/dev/null || echo "?")
        DB=$(python3 -c "import json,sys; d=json.load(open('/tmp/v2c_health.json')); print(d.get('db','?'))" 2>/dev/null || echo "?")
        UPTIME=$(python3 -c "import json,sys; d=json.load(open('/tmp/v2c_health.json')); print(round(d.get('uptime',0)))" 2>/dev/null || echo "?")
        echo -e "         status=${STATUS}  db=${DB}  uptime=${UPTIME}s"
    else
        cat /tmp/v2c_health.json
    fi
else
    echo -e "${FAIL} HTTP /health → ${HTTP_CODE} (expected 200)"
    echo "    Response body (if any):"
    cat /tmp/v2c_health.json 2>/dev/null || true
fi

# ── 3. Docker / Anisette ─────────────────────────────────────────────────────
echo ""
if command -v docker &>/dev/null; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^anisette$'; then
        echo -e "${PASS} Docker container 'anisette' is running"
    else
        echo -e "${FAIL} Docker container 'anisette' is NOT running"
        echo "    Try: docker start anisette"
    fi
else
    echo -e "${INFO}  Docker not installed — skipping anisette check"
fi

# ── 4. Database ──────────────────────────────────────────────────────────────
echo ""
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_FILE="${PROJECT_DIR}/reports.db"
if [ -f "$DB_FILE" ]; then
    DB_SIZE=$(du -sh "$DB_FILE" | cut -f1)
    echo -e "${PASS} Database exists: ${DB_FILE} (${DB_SIZE})"
else
    echo -e "${FAIL} Database not found at ${DB_FILE}"
    echo "    Run: python3 request_reports.py  (first-time Apple auth)"
fi

echo ""
echo "────────────────────────────────────────"
echo -e "${INFO}  Done. Full guide: docs/raspberry-pi-deploy.md"
