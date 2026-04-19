#!/usr/bin/env bash
# ============================================================
# V2C Project — 一键安装脚本
# 适用平台：Raspberry Pi OS（64-bit）/ Debian 系 Linux
#
# 使用方法：
#   bash scripts/install.sh
#
# 脚本将自动完成：
#   1. 检查系统环境
#   2. 更新软件包列表
#   3. 安装 Node.js、Python3、Git 等依赖
#   4. 配置项目目录与环境变量
#   5. 安装项目 npm/pip 依赖
#   6. 注册并启动 systemd 开机自启服务
# ============================================================

set -e  # 遇到错误立即退出

# ——————————————————————————————————————————
# 颜色输出工具函数
# ——————————————————————————————————————————
# 打印带颜色的信息
info()    { echo -e "\033[1;36m[信息]\033[0m $*"; }
success() { echo -e "\033[1;32m[成功]\033[0m $*"; }
warning() { echo -e "\033[1;33m[警告]\033[0m $*"; }
error()   { echo -e "\033[1;31m[错误]\033[0m $*" >&2; }
step()    { echo -e "\n\033[1;34m========== $* ==========\033[0m"; }

# ——————————————————————————————————————————
# 全局配置变量
# ——————————————————————————————————————————
# 项目根目录（脚本所在位置的上一级）
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# systemd 服务文件名
SERVICE_NAME="v2c-project"
# 需要安装的 Node.js 大版本
NODE_MAJOR=20

# ——————————————————————————————————————————
# 步骤 1：检查运行环境
# ——————————————————————————————————————————
step "步骤 1/6：检查运行环境"

# 检查是否为 root 或有 sudo 权限
if [ "$EUID" -eq 0 ]; then
    warning "当前以 root 身份运行，建议使用普通用户 + sudo"
fi

# 检查是否在支持的系统上运行
if ! command -v apt-get &> /dev/null; then
    error "本脚本仅支持 Debian / Ubuntu / Raspberry Pi OS 系统（需要 apt-get）"
    exit 1
fi

# 显示系统信息
info "系统信息：$(uname -m) — $(cat /etc/os-release | grep PRETTY_NAME | cut -d= -f2 | tr -d '\"')"
info "项目目录：$PROJECT_DIR"
success "环境检查通过"

# ——————————————————————————————————————————
# 步骤 2：更新系统软件包
# ——————————————————————————————————————————
step "步骤 2/6：更新系统软件包"
info "正在更新软件包列表，请稍候..."
sudo apt-get update -qq
success "软件包列表更新完成"

# ——————————————————————————————————————————
# 步骤 3：安装运行时依赖
# ——————————————————————————————————————————
step "步骤 3/6：安装运行时依赖"

# 安装基础工具
info "正在安装基础工具（git、curl、build-essential 等）..."
sudo apt-get install -y -qq git curl wget unzip build-essential python3 python3-pip python3-venv
success "基础工具安装完成"

# 安装 Node.js
if command -v node &> /dev/null; then
    CURRENT_NODE_VERSION=$(node -v | sed 's/v//' | cut -d. -f1)
    if [ "$CURRENT_NODE_VERSION" -ge "$NODE_MAJOR" ]; then
        info "Node.js $(node -v) 已安装，跳过"
    else
        warning "当前 Node.js 版本过低（$(node -v)），将升级到 v${NODE_MAJOR}.x..."
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
        sudo apt-get install -y nodejs
        success "Node.js 升级完成：$(node -v)"
    fi
else
    info "正在安装 Node.js v${NODE_MAJOR}.x..."
    curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
    sudo apt-get install -y nodejs
    success "Node.js 安装完成：$(node -v)，npm：$(npm -v)"
fi

# ——————————————————————————————————————————
# 步骤 4：配置环境变量
# ——————————————————————————————————————————
step "步骤 4/6：配置环境变量"

cd "$PROJECT_DIR"

if [ -f ".env" ]; then
    warning ".env 文件已存在，跳过复制（如需重置，请手动删除后重新运行）"
else
    if [ -f ".env.example" ]; then
        cp .env.example .env
        success "已从 .env.example 复制生成 .env 文件"
        info "请编辑 .env 文件，填写数据库密码、JWT 密钥等敏感配置："
        info "  nano $PROJECT_DIR/.env"
    else
        warning ".env.example 不存在，跳过环境变量配置"
    fi
fi

# ——————————————————————————————————————————
# 步骤 5：安装项目依赖
# ——————————————————————————————————————————
step "步骤 5/6：安装项目依赖"

cd "$PROJECT_DIR"

# 安装 Node.js 依赖（如果存在 package.json）
if [ -f "package.json" ]; then
    info "检测到 package.json，正在安装 npm 依赖..."
    npm install --production
    success "npm 依赖安装完成"
else
    info "未检测到 package.json，跳过 npm 依赖安装"
fi

# 安装 Python 依赖（如果存在 requirements.txt）
if [ -f "requirements.txt" ]; then
    info "检测到 requirements.txt，正在安装 Python 依赖..."
    pip3 install -r requirements.txt --quiet
    success "Python 依赖安装完成"
else
    info "未检测到 requirements.txt，跳过 Python 依赖安装"
fi

# 安装 GPIO 演示依赖（仅在树莓派上安装）
if [ -f "/proc/device-tree/model" ] && grep -q "Raspberry" /proc/device-tree/model 2>/dev/null; then
    info "检测到树莓派硬件，安装 GPIO 演示所需依赖（RPi.GPIO、requests）..."
    pip3 install RPi.GPIO requests --quiet
    success "GPIO 依赖安装完成"
else
    info "非树莓派环境，跳过 GPIO 依赖安装"
fi

# ——————————————————————————————————————————
# 步骤 6：注册 systemd 服务
# ——————————————————————————————————————————
step "步骤 6/6：注册 systemd 开机自启服务"

SYSTEMD_SERVICE_SRC="$PROJECT_DIR/systemd/${SERVICE_NAME}.service"
SYSTEMD_SERVICE_DST="/etc/systemd/system/${SERVICE_NAME}.service"

if [ -f "$SYSTEMD_SERVICE_SRC" ]; then
    # 替换服务文件中的路径占位符为实际路径
    CURRENT_USER="${SUDO_USER:-$(whoami)}"
    info "正在配置服务文件，用户：$CURRENT_USER，项目路径：$PROJECT_DIR"

    # 使用 mktemp 生成随机临时文件，避免可预测路径的符号链接攻击
    TMPFILE=$(mktemp)
    sudo sed \
        -e "s|/home/pi/v2c-project|$PROJECT_DIR|g" \
        -e "s|User=pi|User=$CURRENT_USER|g" \
        -e "s|Group=pi|Group=$CURRENT_USER|g" \
        "$SYSTEMD_SERVICE_SRC" > "$TMPFILE"

    sudo cp "$TMPFILE" "$SYSTEMD_SERVICE_DST"
    rm -f "$TMPFILE"
    sudo systemctl daemon-reload
    sudo systemctl enable "$SERVICE_NAME"
    sudo systemctl restart "$SERVICE_NAME"

    sleep 2  # 等待服务启动

    if sudo systemctl is-active --quiet "$SERVICE_NAME"; then
        success "服务已启动并设为开机自启！"
        info "查看服务状态：sudo systemctl status $SERVICE_NAME"
        info "查看实时日志：sudo journalctl -u $SERVICE_NAME -f"
    else
        warning "服务注册成功，但启动时出现问题"
        warning "请检查日志：sudo journalctl -u $SERVICE_NAME -n 50 --no-pager"
    fi
else
    warning "未找到 systemd 服务配置文件：$SYSTEMD_SERVICE_SRC"
    warning "请手动配置 systemd 服务，参考 docs/raspberry-pi-deploy.md"
fi

# ——————————————————————————————————————————
# 完成！打印操作汇总
# ——————————————————————————————————————————
echo ""
echo -e "\033[1;32m╔══════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;32m║          🎉 V2C Project 安装完成！          ║\033[0m"
echo -e "\033[1;32m╚══════════════════════════════════════════════╝\033[0m"
echo ""
info "下一步操作提示："
echo "  1. 编辑环境变量：nano $PROJECT_DIR/.env"
echo "  2. 检查服务状态：bash $PROJECT_DIR/scripts/check.sh"
echo "  3. 查看部署文档：cat $PROJECT_DIR/docs/raspberry-pi-deploy.md"
echo ""
