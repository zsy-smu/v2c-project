#!/bin/bash
# =============================================================
# V2C Project — Jetson 一键部署脚本
# 文件：scripts/setup_jetson.sh
# 适用：NVIDIA Jetson Orin Nano Super 8G，系统 JetPack 6.1（Ubuntu 22.04 aarch64）
# 使用方法：
#   chmod +x scripts/setup_jetson.sh
#   ./scripts/setup_jetson.sh
# =============================================================

# 设置脚本在任意命令失败时立即退出，避免错误继续蔓延
set -e

# -------------------------------------------------------
# 全局变量定义
# -------------------------------------------------------
# 项目根目录（以脚本所在位置的上级目录为准）
项目目录=$(cd "$(dirname "$0")/.." && pwd)

# 当前操作系统用户名（Jetson 默认是 nvidia）
当前用户=$(whoami)

# 后端服务名称（与 systemd 服务文件名对应）
服务名称="v2c-backend"

# systemd 服务文件存放路径
系统服务目录="/etc/systemd/system"

# -------------------------------------------------------
# 彩色输出辅助函数
# -------------------------------------------------------
打印信息() {
    echo -e "\033[32m[信息]\033[0m $1"
}

打印警告() {
    echo -e "\033[33m[警告]\033[0m $1"
}

打印错误() {
    echo -e "\033[31m[错误]\033[0m $1"
}

打印标题() {
    echo ""
    echo -e "\033[36m=========================================\033[0m"
    echo -e "\033[36m  $1\033[0m"
    echo -e "\033[36m=========================================\033[0m"
}

# -------------------------------------------------------
# 检查是否以 root 或 sudo 执行（systemd 操作需要权限）
# -------------------------------------------------------
检查权限() {
    if [ "$EUID" -ne 0 ]; then
        打印警告 "部分操作需要管理员权限，请在提示时输入 sudo 密码"
    fi
}

# -------------------------------------------------------
# 确认当前运行在 Jetson / Ubuntu 22.04 aarch64 环境
# -------------------------------------------------------
检查系统环境() {
    打印标题 "系统环境检查"

    # 检查架构（Jetson 是 aarch64）
    系统架构=$(uname -m)
    打印信息 "系统架构：$系统架构"

    # 检查操作系统
    if [ -f /etc/os-release ]; then
        系统名称=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
        打印信息 "操作系统：$系统名称"
    fi

    # 尝试读取 JetPack 版本
    if [ -f /etc/nv_tegra_release ]; then
        打印信息 "JetPack 版本：$(head -1 /etc/nv_tegra_release)"
    fi

    打印信息 "当前用户：$当前用户"
    打印信息 "项目目录：$项目目录"
}

# -------------------------------------------------------
# 第一步：更新系统软件包
# -------------------------------------------------------
更新系统() {
    打印标题 "第一步：更新系统软件包"
    打印信息 "正在更新软件包列表，请稍候..."
    sudo apt update -qq
    打印信息 "软件包列表更新完成 ✓"
}

# -------------------------------------------------------
# 第二步：安装基础工具
# -------------------------------------------------------
安装基础工具() {
    打印标题 "第二步：安装基础工具"
    打印信息 "正在安装 git、curl、wget、vim、build-essential..."
    sudo apt install -y git curl wget vim build-essential ca-certificates -qq
    打印信息 "基础工具安装完成 ✓"
}

# -------------------------------------------------------
# 第三步：安装 Node.js 运行环境
# JetPack 6.1 基于 Ubuntu 22.04，完全兼容 NodeSource 官方脚本
# -------------------------------------------------------
安装Node环境() {
    打印标题 "第三步：安装 Node.js 运行环境"

    # 检查是否已安装 Node.js
    if command -v node &>/dev/null; then
        当前版本=$(node -v)
        打印信息 "Node.js 已安装，当前版本：$当前版本，跳过此步骤"
        return
    fi

    打印信息 "正在通过 NodeSource 安装 Node.js v20 LTS..."
    打印信息 "（JetPack 6.1 / Ubuntu 22.04 aarch64 完全兼容）"
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - -q
    sudo apt install -y nodejs -qq

    打印信息 "Node.js 安装完成 ✓"
    打印信息 "  Node.js 版本：$(node -v)"
    打印信息 "  npm 版本：$(npm -v)"
}

# -------------------------------------------------------
# 第四步：安装 Python 环境（Jetson.GPIO 和其他脚本依赖）
# -------------------------------------------------------
安装Python环境() {
    打印标题 "第四步：安装 Python 3 运行环境"

    打印信息 "正在安装 Python 3、pip 及虚拟环境工具..."
    sudo apt install -y python3 python3-pip python3-venv -qq

    打印信息 "Python 环境安装完成 ✓"
    打印信息 "  Python 版本：$(python3 --version)"

    # 安装 Jetson.GPIO 库（Jetson 上替代 RPi.GPIO 的 GPIO 控制库）
    打印信息 "正在安装 Jetson.GPIO 库（GPIO 按键功能可选）..."
    pip3 install Jetson.GPIO --quiet 2>/dev/null || \
        打印警告 "Jetson.GPIO 安装跳过（可选，不影响主服务运行）"

    # 将当前用户加入 gpio 用户组（允许无 sudo 操作 GPIO 引脚）
    sudo groupadd -f -r gpio 2>/dev/null || true
    sudo usermod -a -G gpio "$当前用户" 2>/dev/null || true
    打印信息 "用户 $当前用户 已加入 gpio 用户组（重新登录后生效）"
}

# -------------------------------------------------------
# 第五步：安装 Node.js 项目依赖
# -------------------------------------------------------
安装项目依赖() {
    打印标题 "第五步：安装项目依赖"

    cd "$项目目录"

    if [ -f "package.json" ]; then
        打印信息 "检测到 package.json，正在运行 npm install..."
        npm install --silent
        打印信息 "Node.js 项目依赖安装完成 ✓"
    else
        打印警告 "未找到 package.json，跳过 npm install"
    fi

    if [ -f "requirements.txt" ]; then
        打印信息 "检测到 requirements.txt，正在运行 pip install..."
        pip3 install -r requirements.txt -q
        打印信息 "Python 项目依赖安装完成 ✓"
    fi
}

# -------------------------------------------------------
# 第六步：初始化环境变量文件
# -------------------------------------------------------
配置环境变量() {
    打印标题 "第六步：配置环境变量"

    cd "$项目目录"

    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            # 复制模板并将路径中的 /home/pi 替换为当前用户的主目录
            sed "s|/home/pi|/home/$当前用户|g" .env.example > .env
            打印信息 ".env 文件已从模板创建，路径已适配为 /home/$当前用户 ✓"
            打印警告 "请编辑 .env 文件，填写你的实际配置：nano $项目目录/.env"
        else
            打印警告 "未找到 .env.example，请手动创建 .env 文件"
        fi
    else
        打印信息 ".env 文件已存在，跳过创建"
    fi
}

# -------------------------------------------------------
# 第七步：创建日志目录
# -------------------------------------------------------
创建日志目录() {
    打印标题 "第七步：创建日志目录"

    日志目录="$项目目录/logs"
    if [ ! -d "$日志目录" ]; then
        mkdir -p "$日志目录"
        打印信息 "日志目录已创建：$日志目录 ✓"
    else
        打印信息 "日志目录已存在，跳过创建"
    fi
}

# -------------------------------------------------------
# 第八步：安装并启用 systemd 服务
# 优先使用 Jetson 专用服务文件，若不存在则使用通用服务文件
# -------------------------------------------------------
配置系统服务() {
    打印标题 "第八步：配置 systemd 开机自启服务"

    # 优先使用 Jetson 专用服务文件
    if [ -f "$项目目录/deploy/systemd/v2c-backend-jetson.service" ]; then
        服务文件="$项目目录/deploy/systemd/v2c-backend-jetson.service"
        打印信息 "使用 Jetson 专用服务文件"
    elif [ -f "$项目目录/deploy/systemd/${服务名称}.service" ]; then
        服务文件="$项目目录/deploy/systemd/${服务名称}.service"
        打印信息 "使用通用服务文件"
    else
        打印错误 "未找到服务文件，请确认 deploy/systemd/ 目录下有 .service 文件"
        exit 1
    fi

    # 将服务文件中的用户和路径占位符替换为当前用户名
    打印信息 "正在将服务文件中的用户名和路径替换为：$当前用户"
    sudo sed \
        "s/User=nvidia/User=$当前用户/g; \
         s/Group=nvidia/Group=$当前用户/g; \
         s|/home/nvidia|/home/$当前用户|g; \
         s/User=pi/User=$当前用户/g; \
         s/Group=pi/Group=$当前用户/g; \
         s|/home/pi|/home/$当前用户|g" \
        "$服务文件" > "/tmp/${服务名称}.service"

    # 复制服务文件到 systemd 目录
    sudo cp "/tmp/${服务名称}.service" "$系统服务目录/${服务名称}.service"
    打印信息 "服务文件已复制到 $系统服务目录 ✓"

    # 重新加载 systemd 配置
    sudo systemctl daemon-reload
    打印信息 "systemd 配置已重新加载 ✓"

    # 启用开机自启
    sudo systemctl enable "${服务名称}.service"
    打印信息 "开机自启已启用 ✓"

    # 启动服务
    打印信息 "正在启动 V2C 后端服务..."
    sudo systemctl start "${服务名称}.service"

    # 等待 3 秒后检查状态
    sleep 3
    if sudo systemctl is-active --quiet "${服务名称}.service"; then
        打印信息 "V2C 后端服务启动成功 ✓"
    else
        打印警告 "服务可能未能正常启动，请检查日志："
        打印警告 "  sudo journalctl -u ${服务名称}.service -n 50 --no-pager"
        打印警告 "常见原因：.env 文件未填写、端口被占用、依赖未安装完整"
    fi
}

# -------------------------------------------------------
# 完成提示
# -------------------------------------------------------
打印完成提示() {
    打印标题 "🎉 Jetson 部署完成！"

    # 获取本机局域网 IP 地址
    本机IP=$(hostname -I | awk '{print $1}')

    echo ""
    打印信息 "V2C 后端服务已成功部署到 Jetson Orin Nano Super！"
    echo ""
    echo -e "  📡 局域网访问地址：\033[32mhttp://${本机IP}:3000\033[0m"
    echo -e "  📋 查看服务状态：\033[33msudo systemctl status ${服务名称}\033[0m"
    echo -e "  📋 查看实时日志：\033[33msudo journalctl -u ${服务名称} -f\033[0m"
    echo -e "  📋 手动停止服务：\033[33msudo systemctl stop ${服务名称}\033[0m"
    echo -e "  📋 手动重启服务：\033[33msudo systemctl restart ${服务名称}\033[0m"
    echo -e "  📋 一键检查状态：\033[33m./scripts/check_service.sh\033[0m"
    echo ""
    打印警告 "注意：如果 .env 文件中有未填写的配置项，服务可能无法正常运行。"
    打印警告 "请执行：nano $项目目录/.env  完成配置后重启服务。"
    echo ""
    打印信息 "完整部署文档请查阅：docs/jetson-deploy.md"
    echo ""
}

# -------------------------------------------------------
# 主流程：按顺序执行所有步骤
# -------------------------------------------------------
主流程() {
    echo ""
    echo -e "\033[36m====================================================\033[0m"
    echo -e "\033[36m    V2C Project — Jetson 一键部署脚本 v1.0\033[0m"
    echo -e "\033[36m    适用：Jetson Orin Nano Super 8G + JetPack 6.1\033[0m"
    echo -e "\033[36m    项目目录：$项目目录\033[0m"
    echo -e "\033[36m    当前用户：$当前用户\033[0m"
    echo -e "\033[36m====================================================\033[0m"
    echo ""

    检查权限
    检查系统环境
    更新系统
    安装基础工具
    安装Node环境
    安装Python环境
    安装项目依赖
    配置环境变量
    创建日志目录
    配置系统服务
    打印完成提示
}

# 执行主流程
主流程
