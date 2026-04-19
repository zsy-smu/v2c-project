#!/usr/bin/env bash
# check_service.sh — Verify V2C Project service health on Raspberry Pi
# V2C Project — 服务状态检查脚本
# Usage / 使用方法: bash scripts/check_service.sh [host] [port]
set -euo pipefail

HOST="${1:-localhost}"
PORT="${2:-3000}"
URL="http://${HOST}:${PORT}/health"

PASS="\033[1;32m✅\033[0m"
FAIL="\033[1;31m❌\033[0m"
INFO="\033[1;34mℹ️\033[0m"

echo -e "${INFO}  V2C Project — 服务状态检查 / Service Health Check"
echo -e "${INFO}  Target: ${URL}"
echo "────────────────────────────────────────"

# ── 1. systemd units / 检查 systemd 服务状态 ─────────────────────────────────
check_unit() {
    local unit="$1"
    if systemctl is-active --quiet "${unit}" 2>/dev/null; then
        local uptime_info
        uptime_info=$(systemctl show "${unit}" --property=ActiveEnterTimestamp --value 2>/dev/null || true)
        echo -e "${PASS} ${unit} 运行中 (active)  启动时间：${uptime_info}"
    else
        echo -e "${FAIL} ${unit} 未运行"
        echo "    修复：sudo systemctl start ${unit}"
    fi
}

echo ""
echo -e "\033[1m【1】systemd 服务状态\033[0m"
check_unit "v2c-server.service"
check_unit "v2c-report.timer"

# ── 2. HTTP healthcheck / HTTP 健康检查 ──────────────────────────────────────
echo ""
echo -e "\033[1m【2】HTTP 健康检查\033[0m"

if ! command -v curl &>/dev/null; then
    echo -e "${FAIL} curl 未安装 — 请先安装: sudo apt install curl"
    exit 1
fi

HTTP_CODE=$(curl -s -o /tmp/v2c_health.json -w "%{http_code}" --max-time 5 "$URL" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${PASS} HTTP /health → 200 OK"
    if command -v python3 &>/dev/null; then
        STATUS=$(python3 -c "import json; d=json.load(open('/tmp/v2c_health.json')); print(d.get('status','?'))" 2>/dev/null || echo "?")
        DB=$(python3 -c "import json; d=json.load(open('/tmp/v2c_health.json')); print(d.get('db','?'))" 2>/dev/null || echo "?")
        UPTIME=$(python3 -c "import json; d=json.load(open('/tmp/v2c_health.json')); print(round(d.get('uptime',0)))" 2>/dev/null || echo "?")
        echo -e "         status=${STATUS}  db=${DB}  uptime=${UPTIME}s"
    else
        cat /tmp/v2c_health.json
    fi
else
    echo -e "${FAIL} HTTP /health → ${HTTP_CODE}（预期 200）"
    echo "    响应内容："
    cat /tmp/v2c_health.json 2>/dev/null || true
fi

# ── 3. Port listen check / 端口监听检查 ──────────────────────────────────────
echo ""
echo -e "\033[1m【3】端口监听状态\033[0m"
if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":${PORT}"; then
        echo -e "${PASS} 端口 ${PORT} 正在监听"
    else
        echo -e "${FAIL} 端口 ${PORT} 未监听"
    fi
fi

# ── 4. Docker / Anisette ─────────────────────────────────────────────────────
echo ""
echo -e "\033[1m【4】Docker / Anisette 容器\033[0m"
if command -v docker &>/dev/null; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q '^anisette$'; then
        echo -e "${PASS} Docker 容器 'anisette' 正在运行"
    else
        echo -e "${FAIL} Docker 容器 'anisette' 未运行"
        echo "    修复：docker start anisette"
    fi
else
    echo -e "${INFO}  Docker 未安装 — 跳过 Anisette 检查"
fi

# ── 5. Database / 数据库检查 ─────────────────────────────────────────────────
echo ""
echo -e "\033[1m【5】数据库文件\033[0m"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DB_FILE="${PROJECT_DIR}/reports.db"
if [ -f "$DB_FILE" ]; then
    DB_SIZE=$(du -sh "$DB_FILE" | cut -f1)
    echo -e "${PASS} 数据库存在：${DB_FILE} (${DB_SIZE})"
else
    echo -e "${FAIL} 数据库不存在：${DB_FILE}"
    echo "    请先运行：python3 request_reports.py（完成 Apple 认证）"
fi

echo ""
echo "────────────────────────────────────────"
echo -e "${INFO}  完成。详细部署指南：docs/raspberry-pi-deploy.md"
