#!/usr/bin/env bash
# setup_pi.sh — V2C Project 树莓派一键部署脚本 / One-shot Raspberry Pi bootstrap
# 适用：树莓派 4B / 5，Raspberry Pi OS Lite 64-bit
# 使用方法 / Usage:
#   bash scripts/setup_pi.sh
# Run as the 'pi' user (not root). Uses sudo internally where needed.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_VERSION="22"
CURRENT_USER="$(whoami)"

log()  { echo -e "\033[1;32m[信息]\033[0m $*"; }
warn() { echo -e "\033[1;33m[警告]\033[0m $*"; }
die()  { echo -e "\033[1;31m[错误]\033[0m $*" >&2; exit 1; }

print_title() {
    echo ""
    echo -e "\033[36m=========================================\033[0m"
    echo -e "\033[36m  $1\033[0m"
    echo -e "\033[36m=========================================\033[0m"
}

print_title "V2C Project — 树莓派一键部署脚本 v1.1"
echo -e "  项目目录：${PROJECT_DIR}"
echo -e "  当前用户：${CURRENT_USER}"

# Check not running as root directly
if [ "$EUID" -eq 0 ]; then
    warn "建议以普通用户（如 pi）运行此脚本，脚本会在需要时自动 sudo。"
fi

# ── 1. System update / 更新系统软件包 ────────────────────────────────────────
print_title "第一步：更新系统软件包"
log "正在更新软件包列表..."
sudo apt-get update -qq
log "正在升级已安装的软件包..."
sudo apt-get upgrade -y -qq
log "系统升级完成 ✓"

# ── 2. Install system tools / 安装基础工具 ───────────────────────────────────
print_title "第二步：安装基础工具"
log "正在安装 git、curl、wget、vim、sqlite3..."
sudo apt-get install -y -qq \
    git curl wget vim ca-certificates \
    python3 python3-pip python3-venv \
    sqlite3
log "基础工具安装完成 ✓"

# ── 3. Docker / 安装 Docker ───────────────────────────────────────────────────
print_title "第三步：安装 Docker"
if ! command -v docker &>/dev/null; then
    log "正在安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$CURRENT_USER"
    warn "Docker 已安装。如需立即使用，请执行 'newgrp docker' 或重新登录。"
else
    log "Docker 已安装：$(docker --version)"
fi

# ── 4. Node.js via nvm / 安装 Node.js ────────────────────────────────────────
print_title "第四步：安装 Node.js ${NODE_VERSION}（nvm）"
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    log "正在安装 nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
log "正在安装 Node.js ${NODE_VERSION}..."
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
log "Node.js 安装完成：$(node -v)  npm：$(npm -v) ✓"

# ── 5. Python venv + dependencies / 安装 Python 环境 ─────────────────────────
print_title "第五步：安装 Python 虚拟环境和依赖"
log "正在创建 venv..."
python3 -m venv "$PROJECT_DIR/venv"
log "正在安装 Python 依赖（aiohttp requests cryptography pycryptodome srp pbkdf2）..."
"$PROJECT_DIR/venv/bin/pip3" install --upgrade pip -q
"$PROJECT_DIR/venv/bin/pip3" install -q \
    aiohttp requests cryptography pycryptodome srp pbkdf2
log "Python 环境配置完成 ✓"

# ── 6. Node.js project dependencies / 安装项目 Node 依赖 ─────────────────────
print_title "第六步：安装项目 Node.js 依赖"
cd "$PROJECT_DIR"
npm install --silent
log "npm install 完成 ✓"

# ── 7. Environment file / 配置环境变量 ───────────────────────────────────────
print_title "第七步：配置环境变量"
if [ ! -f "$PROJECT_DIR/.env" ]; then
    log "正在从 .env.example 创建 .env..."
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    # Default to venv python
    sed -i "s|^PYTHON_CMD=.*|PYTHON_CMD=$PROJECT_DIR/venv/bin/python3|" "$PROJECT_DIR/.env"
    warn "请编辑 $PROJECT_DIR/.env 填写实际配置（Apple ID 账号等）。"
    warn "执行：nano $PROJECT_DIR/.env"
else
    log ".env 已存在，跳过创建。"
fi

# ── 8. Keys directory / 创建 keys 目录 ───────────────────────────────────────
mkdir -p "$PROJECT_DIR/keys"
log "keys/ 目录已就绪，请将 .key 文件放入：$PROJECT_DIR/keys/"

# ── 9. Logs directory / 创建日志目录 ─────────────────────────────────────────
mkdir -p "$PROJECT_DIR/logs"
log "logs/ 目录已就绪 ✓"

# ── 10. Anisette Docker container / 启动 Anisette 容器 ───────────────────────
print_title "第八步：启动 Anisette Docker 容器"
docker network create mh-network 2>/dev/null || true
if ! docker ps -a --format '{{.Names}}' | grep -q '^anisette$'; then
    log "正在拉取并启动 Anisette 容器..."
    docker run -d --restart always --name anisette \
        -p 6969:6969 \
        --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/ \
        --network mh-network \
        dadoum/anisette-v3-server
    log "Anisette 容器已启动 ✓"
else
    docker start anisette 2>/dev/null || true
    log "Anisette 容器已存在，确保运行中 ✓"
fi

# ── 11. systemd services / 配置 systemd 开机自启 ─────────────────────────────
print_title "第九步：配置 systemd 开机自启"

NODE_BIN_PATH="$(nvm which "$NODE_VERSION" 2>/dev/null || which node)"
NODE_BIN_DIR="$(dirname "$NODE_BIN_PATH")"

for UNIT in v2c-server.service v2c-report.service v2c-report.timer; do
    SRC="$PROJECT_DIR/deploy/systemd/$UNIT"
    DST="/etc/systemd/system/$UNIT"
    sed \
        -e "s|/home/pi/v2c-project|$PROJECT_DIR|g" \
        -e "s|User=pi|User=$CURRENT_USER|g" \
        -e "s|/home/pi/.nvm/versions/node/v22/bin|$NODE_BIN_DIR|g" \
        "$SRC" | sudo tee "$DST" > /dev/null
    log "  已安装：$UNIT → $DST"
done

sudo systemctl daemon-reload
sudo systemctl enable --now v2c-server.service
sudo systemctl enable --now v2c-report.timer
log "systemd 服务配置完成，开机自启已启用 ✓"

# ── 12. GPIO library (optional) / 可选 GPIO 库 ───────────────────────────────
if grep -q "^ENABLE_GPIO=true" "$PROJECT_DIR/.env" 2>/dev/null; then
    log "检测到 ENABLE_GPIO=true，正在安装 RPi.GPIO 库..."
    "$PROJECT_DIR/venv/bin/pip3" install -q RPi.GPIO
fi

# ── Done / 完成 ───────────────────────────────────────────────────────────────
LOCAL_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "树莓派IP")

print_title "🎉 部署完成！"
echo ""
log "V2C 后端服务已成功部署到树莓派！"
echo ""
echo -e "  📡 局域网访问地址：\033[32mhttp://${LOCAL_IP}:3000\033[0m"
echo -e "  🩺 健康检查：\033[33mcurl http://localhost:3000/health\033[0m"
echo -e "  📋 查看服务状态：\033[33msudo systemctl status v2c-server\033[0m"
echo -e "  📋 查看实时日志：\033[33msudo journalctl -u v2c-server -f\033[0m"
echo ""
warn "下一步："
warn "  1. 复制 .key 文件到 $PROJECT_DIR/keys/"
warn "  2. 完成 Apple 认证：cd $PROJECT_DIR && python3 request_reports.py"
warn "  3. 验证服务：bash $PROJECT_DIR/scripts/check_service.sh"
warn "  4. 完整部署文档：$PROJECT_DIR/docs/raspberry-pi-deploy.md"
echo ""
