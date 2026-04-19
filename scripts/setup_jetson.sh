#!/bin/bash
# =============================================================
# V2C Project — Jetson 一键部署脚本
# 文件：scripts/setup_jetson.sh
# 适用：NVIDIA Jetson Orin Nano / Xavier / Nano，JetPack 5.x / 6.x
# 使用方法（在 Jetson 上 MobaXterm/SSH 终端中执行）：
#   chmod +x scripts/setup_jetson.sh
#   ./scripts/setup_jetson.sh
#
# 树莓派用户请改用：scripts/setup_pi.sh
# =============================================================

# 设置脚本在任意命令失败时立即退出，避免错误继续蔓延
set -e

# -------------------------------------------------------
# 全局变量定义
# -------------------------------------------------------
# 项目根目录（以脚本所在位置的上级目录为准）
项目目录=$(cd "$(dirname "$0")/.." && pwd)

# 当前操作系统用户名
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
        打印警告 "部分操作需要管理员权限，请在提示时输入密码"
    fi
}

# -------------------------------------------------------
# 检查 Jetson 环境
# -------------------------------------------------------
检查Jetson环境() {
    打印标题 "环境检查：Jetson / JetPack"

    if [ -f /etc/nv_tegra_release ]; then
        打印信息 "检测到 Jetson 设备 ✓"
        打印信息 "  JetPack 版本信息：$(head -1 /etc/nv_tegra_release)"
    else
        打印警告 "未检测到标准 Jetson 环境（/etc/nv_tegra_release 不存在）"
        打印警告 "脚本将继续运行，但部分 Jetson 专属步骤可能跳过"
    fi

    打印信息 "  系统版本：$(uname -a)"
    打印信息 "  当前用户：$当前用户"
}

# -------------------------------------------------------
# 第一步：更新系统软件包
# -------------------------------------------------------
更新系统() {
    打印标题 "第一步：更新系统软件包"
    打印信息 "正在更新软件包列表，请稍候..."
    sudo apt update -qq
    打印信息 "软件包列表更新完成"

    打印信息 "正在升级已安装的软件包..."
    sudo apt upgrade -y -qq
    打印信息 "系统升级完成 ✓"
}

# -------------------------------------------------------
# 第二步：安装基础工具
# -------------------------------------------------------
安装基础工具() {
    打印标题 "第二步：安装基础工具"
    打印信息 "正在安装 git、curl、wget、vim..."
    sudo apt install -y git curl wget vim -qq
    打印信息 "基础工具安装完成 ✓"
}

# -------------------------------------------------------
# 第三步：安装 Node.js 运行环境
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
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - -q
    sudo apt install -y nodejs -qq

    打印信息 "Node.js 安装完成 ✓"
    打印信息 "  Node.js 版本：$(node -v)"
    打印信息 "  npm 版本：$(npm -v)"
}

# -------------------------------------------------------
# 第四步：安装 Python 环境（Jetson 专用：Jetson.GPIO）
# -------------------------------------------------------
安装Python环境() {
    打印标题 "第四步：安装 Python 3 运行环境（Jetson）"

    打印信息 "正在安装 Python 3、pip..."
    sudo apt install -y python3 python3-pip python3-venv -qq

    打印信息 "Python 环境安装完成 ✓"
    打印信息 "  Python 版本：$(python3 --version)"

    # 安装 Jetson.GPIO（Jetson 专用 GPIO 库，与 RPi.GPIO API 兼容）
    打印信息 "正在安装 Jetson.GPIO..."
    if pip3 install Jetson.GPIO -q 2>/dev/null; then
        打印信息 "Jetson.GPIO 安装完成 ✓"
    else
        打印警告 "Jetson.GPIO 安装失败，请手动执行：sudo pip3 install Jetson.GPIO"
    fi

    # 将当前用户加入 gpio 用户组（避免每次需要 sudo）
    if getent group gpio > /dev/null 2>&1; then
        sudo usermod -a -G gpio "$当前用户"
        打印信息 "已将用户 $当前用户 加入 gpio 用户组（重新登录后生效）✓"
    else
        # 创建 gpio 用户组（部分 Jetson 镜像默认无此组）
        sudo groupadd -f -r gpio
        sudo usermod -a -G gpio "$当前用户"
        打印信息 "已创建 gpio 用户组并添加当前用户（重新登录后生效）✓"
    fi
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
            cp .env.example .env
            打印信息 ".env 文件已从模板创建 ✓"
            打印警告 "请编辑 .env 文件，填写你的实际配置：nano $项目目录/.env"
            打印警告 "重点配置项：JETSON_DEVICE_IP、CONTROLLER_IP、PORT"
        else
            打印警告 "未找到 .env.example，请手动创建 .env 文件"
        fi
    else
        打印信息 ".env 文件已存在，跳过创建"
    fi
}

# -------------------------------------------------------
# 第七步：安装并启用 systemd 服务
# -------------------------------------------------------
配置系统服务() {
    打印标题 "第七步：配置 systemd 开机自启服务"

    服务文件="$项目目录/deploy/systemd/${服务名称}.service"

    if [ ! -f "$服务文件" ]; then
        打印错误 "未找到服务文件：$服务文件"
        打印错误 "请确认 deploy/systemd/${服务名称}.service 文件存在"
        return 1
    fi

    # 将服务文件中的用户占位符替换为当前用户名（支持 nvidia 或其他用户）
    打印信息 "正在将服务文件中的用户名替换为：$当前用户"
    sudo sed "s/User=nvidia/User=$当前用户/g; s/Group=nvidia/Group=$当前用户/g; s|/home/nvidia|/home/$当前用户|g" \
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

    # 等待 2 秒后检查状态
    sleep 2
    if sudo systemctl is-active --quiet "${服务名称}.service"; then
        打印信息 "V2C 后端服务启动成功 ✓"
    else
        打印警告 "服务可能未能正常启动，请检查日志："
        打印警告 "  sudo journalctl -u ${服务名称}.service -n 30 --no-pager"
    fi
}

# -------------------------------------------------------
# 第八步：创建日志目录
# -------------------------------------------------------
创建日志目录() {
    打印标题 "第八步：创建日志目录"

    日志目录="$项目目录/logs"
    if [ ! -d "$日志目录" ]; then
        mkdir -p "$日志目录"
        打印信息 "日志目录已创建：$日志目录 ✓"
    else
        打印信息 "日志目录已存在，跳过创建"
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
    打印信息 "V2C 后端服务已成功部署到 Jetson！"
    echo ""
    echo -e "  📡 MobaXterm 可访问地址：\033[32mhttp://${本机IP}:3000\033[0m"
    echo -e "  📋 查看服务状态：\033[33msudo systemctl status ${服务名称}\033[0m"
    echo -e "  📋 查看实时日志：\033[33msudo journalctl -u ${服务名称} -f\033[0m"
    echo -e "  📋 手动停止服务：\033[33msudo systemctl stop ${服务名称}\033[0m"
    echo -e "  📋 手动重启服务：\033[33msudo systemctl restart ${服务名称}\033[0m"
    echo ""
    打印警告 "注意：如果 .env 文件中有未填写的配置项，服务可能无法正常运行。"
    打印警告 "请执行：nano $项目目录/.env  完成配置后重启服务。"
    echo ""
    打印警告 "提示：GPIO 用户组变更需要重新登录 SSH 后才能生效。"
    echo ""
}

# -------------------------------------------------------
# 主流程：按顺序执行所有步骤
# -------------------------------------------------------
主流程() {
    echo ""
    echo -e "\033[36m====================================================\033[0m"
    echo -e "\033[36m    V2C Project — Jetson 一键部署脚本 v1.0\033[0m"
    echo -e "\033[36m    项目目录：$项目目录\033[0m"
    echo -e "\033[36m    当前用户：$当前用户\033[0m"
    echo -e "\033[36m====================================================\033[0m"
    echo ""

    检查权限
    检查Jetson环境
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
