#!/usr/bin/env bash
# ============================================================
# V2C Project — 环境检测脚本
# 用于快速诊断服务运行状态、依赖版本、配置完整性
#
# 使用方法：
#   bash scripts/check.sh
# ============================================================

# ——————————————————————————————————————————
# 颜色输出工具函数
# ——————————————————————————————————————————
GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
RESET='\033[0m'

ok()   { echo -e "  ${GREEN}✔${RESET}  $*"; }
fail() { echo -e "  ${RED}✘${RESET}  $*"; FAILED=$((FAILED+1)); }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; WARNED=$((WARNED+1)); }
section() { echo -e "\n${CYAN}▶ $*${RESET}"; }

# ——————————————————————————————————————————
# 计数器初始化
# ——————————————————————————————————————————
FAILED=0
WARNED=0

# 项目根目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE_NAME="v2c-project"

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════╗${RESET}"
echo -e "${CYAN}║      V2C Project — 环境检测报告              ║${RESET}"
echo -e "${CYAN}╚══════════════════════════════════════════════╝${RESET}"
echo -e "  检测时间：$(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  项目目录：$PROJECT_DIR"

# ——————————————————————————————————————————
# 1. 检查系统环境
# ——————————————————————————————————————————
section "系统环境"

# 操作系统
OS_INFO=$(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo "未知")
ok "操作系统：$OS_INFO"

# 系统架构
ARCH=$(uname -m)
ok "系统架构：$ARCH"

# 是否为树莓派
if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry" /proc/device-tree/model 2>/dev/null; then
    RPI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "未知型号")
    ok "硬件平台：$RPI_MODEL（树莓派）"
else
    warn "硬件平台：非树莓派环境（GPIO 功能不可用）"
fi

# 内存使用
if command -v free &>/dev/null; then
    MEM_TOTAL=$(free -m | awk '/^Mem:/ {print $2}')
    MEM_USED=$(free -m | awk '/^Mem:/ {print $3}')
    MEM_FREE=$(free -m | awk '/^Mem:/ {print $4}')
    ok "内存状态：总计 ${MEM_TOTAL}MB，已用 ${MEM_USED}MB，空闲 ${MEM_FREE}MB"
fi

# 磁盘空间
DISK_INFO=$(df -h "$PROJECT_DIR" 2>/dev/null | tail -1 | awk '{print "总计 "$2"，已用 "$3"（"$5"），可用 "$4}')
ok "磁盘空间：$DISK_INFO"

# ——————————————————————————————————————————
# 2. 检查依赖工具版本
# ——————————————————————————————————————————
section "依赖工具版本"

# Node.js
if command -v node &>/dev/null; then
    NODE_VER=$(node -v)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
        ok "Node.js：$NODE_VER ✓"
    else
        warn "Node.js：$NODE_VER（建议 v18 或更高版本）"
    fi
else
    fail "Node.js：未安装"
fi

# npm
if command -v npm &>/dev/null; then
    ok "npm：$(npm -v)"
else
    fail "npm：未安装"
fi

# Python3
if command -v python3 &>/dev/null; then
    ok "Python3：$(python3 --version 2>&1 | awk '{print $2}')"
else
    warn "Python3：未安装（GPIO 演示脚本需要）"
fi

# pip3
if command -v pip3 &>/dev/null; then
    ok "pip3：$(pip3 --version | awk '{print $2}')"
else
    warn "pip3：未安装"
fi

# Git
if command -v git &>/dev/null; then
    ok "Git：$(git --version | awk '{print $3}')"
else
    fail "Git：未安装"
fi

# curl
if command -v curl &>/dev/null; then
    ok "curl：已安装"
else
    warn "curl：未安装"
fi

# ——————————————————————————————————————————
# 3. 检查项目文件完整性
# ——————————————————————————————————————————
section "项目文件完整性"

# 必要文件检查
REQUIRED_FILES=(
    "index.html"
    ".env.example"
    "docs/raspberry-pi-deploy.md"
    "systemd/v2c-project.service"
    "scripts/install.sh"
    "scripts/check.sh"
    "scripts/gpio_demo.py"
)

for FILE in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_DIR/$FILE" ]; then
        ok "$FILE"
    else
        warn "$FILE（文件不存在）"
    fi
done

# .env 配置文件
if [ -f "$PROJECT_DIR/.env" ]; then
    ok ".env（环境变量文件已配置）"
else
    warn ".env（未配置，请先执行：cp .env.example .env）"
fi

# package.json（可选）
if [ -f "$PROJECT_DIR/package.json" ]; then
    ok "package.json（Node.js 项目配置文件存在）"
    # 检查 node_modules 是否已安装
    if [ -d "$PROJECT_DIR/node_modules" ]; then
        ok "node_modules（npm 依赖已安装）"
    else
        warn "node_modules（npm 依赖未安装，请执行：npm install）"
    fi
fi

# requirements.txt（可选）
if [ -f "$PROJECT_DIR/requirements.txt" ]; then
    ok "requirements.txt（Python 依赖清单存在）"
fi

# ——————————————————————————————————————————
# 4. 检查 systemd 服务状态
# ——————————————————————————————————————————
section "systemd 服务状态"

if command -v systemctl &>/dev/null; then
    # 检查服务是否已注册
    if systemctl list-unit-files "${SERVICE_NAME}.service" 2>/dev/null | grep -q "$SERVICE_NAME"; then
        # 检查服务是否启用（开机自启）
        if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
            ok "服务注册状态：已注册并设为开机自启"
        else
            warn "服务注册状态：已注册，但未设为开机自启"
        fi

        # 检查服务是否正在运行
        if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
            ok "服务运行状态：✅ 正在运行"
        else
            FAILED_REASON=$(systemctl status "$SERVICE_NAME" 2>&1 | grep "Active:" | head -1 | xargs)
            fail "服务运行状态：未运行 — $FAILED_REASON"
        fi
    else
        warn "服务注册状态：尚未注册（请运行安装脚本：bash scripts/install.sh）"
    fi
else
    warn "systemctl 不可用（非 systemd 系统）"
fi

# ——————————————————————————————————————————
# 5. 检查网络可访问性
# ——————————————————————————————————————————
section "网络状态"

# 获取 .env 中配置的端口（如果存在）
if [ -f "$PROJECT_DIR/.env" ]; then
    SERVICE_PORT=$(grep "^PORT=" "$PROJECT_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d ' ')
else
    SERVICE_PORT="3000"
fi
SERVICE_PORT="${SERVICE_PORT:-3000}"

# 检查端口是否被监听
if command -v ss &>/dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":${SERVICE_PORT}"; then
        ok "端口 $SERVICE_PORT：正在监听（服务已就绪）"
    else
        warn "端口 $SERVICE_PORT：未监听（服务可能未启动）"
    fi
elif command -v netstat &>/dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":${SERVICE_PORT}"; then
        ok "端口 $SERVICE_PORT：正在监听（服务已就绪）"
    else
        warn "端口 $SERVICE_PORT：未监听（服务可能未启动）"
    fi
fi

# 获取本机 IP
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}')
if [ -n "$LOCAL_IP" ]; then
    ok "本机 IP 地址：$LOCAL_IP"
    ok "局域网访问地址：http://${LOCAL_IP}:${SERVICE_PORT}"
fi

# ——————————————————————————————————————————
# 6. 检查 GPIO 环境（仅树莓派）
# ——————————————————————————————————————————
if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry" /proc/device-tree/model 2>/dev/null; then
    section "GPIO 环境"

    # 检查 RPi.GPIO Python 库
    if python3 -c "import RPi.GPIO" 2>/dev/null; then
        ok "RPi.GPIO 库：已安装"
    else
        warn "RPi.GPIO 库：未安装（GPIO 演示需要，运行：pip3 install RPi.GPIO）"
    fi

    # 检查 requests Python 库
    if python3 -c "import requests" 2>/dev/null; then
        ok "requests 库：已安装"
    else
        warn "requests 库：未安装（GPIO 演示需要，运行：pip3 install requests）"
    fi
fi

# ——————————————————————————————————————————
# 汇总报告
# ——————————————————————————————————————————
echo ""
echo -e "${CYAN}══════════════════════════════════════════════${RESET}"

if [ "$FAILED" -eq 0 ] && [ "$WARNED" -eq 0 ]; then
    echo -e "  ${GREEN}🎉 全部检测通过！环境配置完整。${RESET}"
elif [ "$FAILED" -eq 0 ]; then
    echo -e "  ${YELLOW}⚠  发现 $WARNED 个警告，请酌情处理。${RESET}"
else
    echo -e "  ${RED}✘  发现 $FAILED 个错误，$WARNED 个警告，请修复后重试。${RESET}"
fi

echo -e "${CYAN}══════════════════════════════════════════════${RESET}"
echo ""

# 返回退出码（有错误则返回 1）
exit $FAILED
