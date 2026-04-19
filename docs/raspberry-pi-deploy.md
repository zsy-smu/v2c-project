# V2C Project — 树莓派实体部署手册 / Raspberry Pi Deployment Guide

> 本文档面向中文开发者，提供从零开始在树莓派上完整部署 V2C Project 后端服务的全流程指引。  
> This guide covers end-to-end deployment of the V2C/NinjiaTag backend on a Raspberry Pi 4B/5.

---

## 目录 / Contents

1. [硬件准备](#1-硬件准备)
2. [烧录树莓派系统](#2-烧录树莓派系统)
3. [首次开机与基础配置](#3-首次开机与基础配置)
4. [SSH 远程连接设置](#4-ssh-远程连接设置)
5. [安装运行环境依赖](#5-安装运行环境依赖)
6. [拉取项目代码](#6-拉取项目代码)
7. [配置环境变量](#7-配置环境变量)
8. [首次 Apple 认证](#8-首次-apple-认证)
9. [启动后端服务](#9-启动后端服务)
10. [配置开机自启（systemd）](#10-配置开机自启systemd)
11. [局域网访问验证](#11-局域网访问验证)
12. [可选：GPIO 按钮触发](#12-可选gpio-按钮触发)
13. [常见问题排查](#13-常见问题排查)

---

## 1. 硬件准备

| 硬件 | 规格建议 | 备注 |
|------|----------|------|
| 树莓派 | 4B（4GB 内存）或 Pi 5 | 推荐 4GB 以上 |
| MicroSD 卡 | 32GB+，Class 10 / A1 | 推荐三星或闪迪品牌 |
| 电源 | 官方 5V 3A USB-C 电源 | 劣质电源会导致随机重启 |
| 散热外壳 | 带风扇的铝合金外壳 | 长时间运行必备 |
| 网线（可选） | 标准以太网线 | 首次配置建议有线连接 |
| HDMI 线（可选） | Micro-HDMI 转 HDMI | 调试时接显示器使用 |
| USB 读卡器 | 任意品牌 | 烧录系统用 |
| 物理按钮（可选） | 轻触开关 + 杜邦线 | GPIO 演示交互用 |

---

## 2. 烧录树莓派系统

1. 前往 [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/) 下载 **Raspberry Pi Imager**。
2. 选择 **Raspberry Pi OS Lite (64-bit)**（无桌面，节省资源）。
3. 点击齿轮图标进行高级设置：
   - ✅ 启用 SSH（密码验证）
   - ✅ 设置用户名和密码（建议用户名 `pi`）
   - ✅ 配置 Wi-Fi（如不用网线）
   - ✅ 时区设置为 `Asia/Shanghai`，主机名设为 `v2c-pi`
4. 烧录，等待约 5-10 分钟，插入树莓派。

---

## 3. 首次开机与基础配置

接好电源，等待约 1-2 分钟，然后在同局域网设备上：

```bash
# 找到树莓派 IP
ping v2c-pi.local
# 或扫描局域网
nmap -sn 192.168.1.0/24 | grep -A 2 "Raspberry"
```

SSH 登录后更新系统：

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

---

## 4. SSH 远程连接设置

```bash
ssh pi@v2c-pi.local
# 或 ssh pi@192.168.x.x
```

**建议固定 IP（避免演示时 IP 变动）：**

```bash
sudo nano /etc/dhcpcd.conf
# 在文件末尾添加：
# interface eth0
# static ip_address=192.168.1.200/24
# static routers=192.168.1.1
# static domain_name_servers=8.8.8.8
sudo systemctl restart dhcpcd
```

---

## 5. 安装运行环境依赖

```bash
# 基础工具
sudo apt install -y git curl wget vim sqlite3 python3 python3-pip python3-venv

# Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

> **国内 Docker 镜像加速**（如果 Docker Hub 拉取慢）：  
> 编辑 `/etc/docker/daemon.json`：
> ```json
> {
>   "registry-mirrors": [
>     "https://docker.1ms.run",
>     "https://hub.1panel.dev",
>     "https://docker.itelyou.cf"
>   ]
> }
> ```
> 然后 `sudo systemctl restart docker`。

**安装 Node.js（推荐 nvm 方式）：**

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install 22
node -v   # v22.x.x
npm -v
```

**Python 依赖：**

```bash
# 系统全局安装（简单）
pip3 install aiohttp requests cryptography pycryptodome srp pbkdf2

# 或使用虚拟环境（推荐）
python3 -m venv ~/v2c-project/venv
~/v2c-project/venv/bin/pip3 install aiohttp requests cryptography pycryptodome srp pbkdf2
```

---

## 6. 拉取项目代码

```bash
cd ~
git clone https://github.com/zsy-smu/v2c-project.git
cd v2c-project
npm install
```

---

## 7. 配置环境变量

```bash
cp .env.example .env
nano .env
```

关键配置项：

| 变量 | 示例值 | 说明 |
|------|--------|------|
| `PORT` | `3000` | API 服务端口 |
| `DB_PATH` | `./reports.db` | SQLite 数据库路径 |
| `PYTHON_CMD` | `./venv/bin/python3` | Python 可执行路径 |
| `ANISETTE_SERVER` | `http://localhost:6969` | Anisette Docker 地址 |
| `JETSON_HOST` | `192.168.1.50` | Jetson 设备局域网 IP |
| `CONTROL_HOST` | `192.168.1.60` | 控制端（G1 / MuJoCo）地址 |
| `ENABLE_GPIO` | `false` | 是否启用 GPIO 按键 |
| `GPIO_BUTTON_PIN` | `18` | BCM 引脚编号 |

**启动 Anisette Docker 容器：**

```bash
docker network create mh-network
docker run -d --restart always --name anisette \
  -p 6969:6969 \
  --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/ \
  --network mh-network \
  dadoum/anisette-v3-server

# 验证
docker ps | grep anisette
```

**放置硬件 Key 文件：**

```bash
# 从笔记本复制 .key 文件到树莓派
scp /path/to/your/*.key pi@v2c-pi.local:~/v2c-project/keys/
```

---

## 8. 首次 Apple 认证

```bash
cd ~/v2c-project
python3 request_reports.py
# 按提示输入 Apple ID、密码和短信验证码
# 完成后会在本地缓存凭证，后续自动执行无需手动操作
```

---

## 9. 启动后端服务

```bash
# 手动测试（验证 server.mjs 正常启动）
npm start
# 看到 "Server running on port 3000" 后按 Ctrl+C 停止
# 后续由 systemd 管理，不需要手动启动
```

---

## 10. 配置开机自启（systemd）

```bash
# 安装 systemd 服务文件
sudo cp deploy/systemd/v2c-server.service  /etc/systemd/system/
sudo cp deploy/systemd/v2c-report.service  /etc/systemd/system/
sudo cp deploy/systemd/v2c-report.timer    /etc/systemd/system/

# 路径替换（如果用户名不是 pi，需要修改服务文件中的路径）
# sudo sed -i "s|/home/pi|/home/$USER|g" /etc/systemd/system/v2c-*.service

# 重新加载配置
sudo systemctl daemon-reload

# 启用并立即启动
sudo systemctl enable --now v2c-server.service
sudo systemctl enable --now v2c-report.timer

# 查看状态
sudo systemctl status v2c-server
sudo systemctl status v2c-report.timer
```

---

## 11. 局域网访问验证

```bash
# 在树莓派上
curl http://localhost:3000/health

# 在同局域网的其他设备上
curl http://v2c-pi.local:3000/health
# 或 curl http://192.168.x.x:3000/health
```

期望返回：

```json
{"status":"ok","db":"connected","port":3000,"uptime":42.1,"timestamp":"..."}
```

或使用验证脚本：

```bash
bash scripts/check_service.sh
```

---

## 12. 可选：GPIO 按钮触发

将轻触按钮的一端接 BCM GPIO 18，另一端接 GND（任意 GND 引脚即可，内部上拉电阻已启用，无需外接电阻）。

在 `.env` 中开启：

```
ENABLE_GPIO=true
GPIO_BUTTON_PIN=18
GPIO_TRIGGER_URL=http://localhost:3000/health
```

安装 GPIO 库并运行：

```bash
pip3 install RPi.GPIO requests
python3 scripts/gpio_trigger.py
```

按下按钮时，`GPIO_TRIGGER_URL` 会收到 GET 请求，可自定义为任意后端接口。

> **注意：** `ENABLE_GPIO=false`（默认）时，`gpio_trigger.py` 启动后立即退出，不访问任何 GPIO 引脚，不影响正常运行。

---

## 13. 常见问题排查

| 现象 | 解决方法 |
|------|---------|
| SSH 连接超时 | 确认 Pi IP，`sudo systemctl start ssh` |
| `curl /health` 返回 503 | 数据库未初始化；先运行 `python3 request_reports.py` |
| 3000 端口局域网不可达 | `sudo ufw allow 3000` |
| Docker 镜像拉取失败 | 配置国内镜像加速（见第 5 节） |
| `gsa_authenticate` 503 错误 | 当前 IP 被 Apple 封禁，换网络或换 IP 重试 |
| GPIO 按钮无响应 | 检查接线、BCM 引脚号、确认 `ENABLE_GPIO=true` |
| npm install 失败 | `npm cache clean --force && npm install` |
| 服务启动失败 | `sudo journalctl -u v2c-server -n 50 --no-pager` 查看详细日志 |

---

*文档版本：v1.1 | 更新：2026年4月 | 维护者：Zsy @ 上海海事大学*
