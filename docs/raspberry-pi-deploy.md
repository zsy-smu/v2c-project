# V2C Project — 树莓派实体部署手册

> 本文档面向中文开发者，提供从零开始在树莓派上完整部署 V2C Project 后端服务的全流程指引。
> 所有命令均可直接复制执行，所有说明均使用中文。

---

## 目录

1. [硬件准备](#1-硬件准备)
2. [烧录树莓派系统](#2-烧录树莓派系统)
3. [首次开机与基础配置](#3-首次开机与基础配置)
4. [SSH 远程连接设置](#4-ssh-远程连接设置)
5. [安装运行环境依赖](#5-安装运行环境依赖)
6. [拉取项目代码](#6-拉取项目代码)
7. [配置环境变量](#7-配置环境变量)
8. [启动后端服务](#8-启动后端服务)
9. [配置开机自启（systemd）](#9-配置开机自启systemd)
10. [局域网访问验证](#10-局域网访问验证)
11. [常见问题排查](#11-常见问题排查)

---

## 1. 硬件准备

| 硬件 | 规格建议 | 备注 |
|------|----------|------|
| 树莓派 | 4B（4GB 内存）或更高 | 推荐 4GB 以上运行流畅 |
| MicroSD 卡 | 32GB 以上，Class 10/A1 | 推荐使用三星或闪迪品牌 |
| 电源 | 官方 5V 3A USB-C 电源 | 劣质电源会导致随机重启 |
| 散热外壳 | 带风扇的铝合金外壳 | 长时间运行必备 |
| 网线（可选） | 标准以太网线 | 首次配置建议有线连接，稳定可靠 |
| HDMI 线（可选） | Micro-HDMI 转标准 HDMI | 调试时接显示器使用 |
| USB 读卡器 | 任意品牌 | 电脑端烧录系统用 |
| 物理按钮（可选） | 轻触开关 + 杜邦线 | 用于 GPIO 演示交互 |

---

## 2. 烧录树莓派系统

### 第一步：下载烧录工具

前往 [https://www.raspberrypi.com/software/](https://www.raspberrypi.com/software/) 下载 **Raspberry Pi Imager**，支持 Windows、macOS、Linux。

### 第二步：烧录系统镜像

1. 插入 MicroSD 卡到读卡器，连接电脑
2. 打开 Raspberry Pi Imager
3. 点击「选择设备」→ 选择你的树莓派型号
4. 点击「选择操作系统」→ 选择 **Raspberry Pi OS Lite (64-bit)**（无桌面，节省资源）
5. 点击「选择存储卡」→ 选择你的 SD 卡（**注意：此操作会清除 SD 卡所有数据**）
6. 点击右下角「齿轮图标」进行高级设置：
   - ✅ 勾选「启用 SSH」，选择「使用密码验证」
   - ✅ 勾选「设置用户名和密码」，填写你的用户名和密码（记住！）
   - ✅ 勾选「配置无线局域网」，填写 WiFi 名称和密码（如果用 WiFi）
   - ✅ 勾选「设置语言」，选择 `Asia/Shanghai` 时区
7. 点击「烧录」，等待完成（约 5-10 分钟）

> **提示**：烧录完成后无需任何额外操作，SD 卡直接插入树莓派即可。

---

## 3. 首次开机与基础配置

1. 将烧录好的 SD 卡插入树莓派
2. 连接电源，等待约 1-2 分钟让系统完成首次启动
3. 通过路由器管理界面或局域网扫描工具找到树莓派的 IP 地址

```bash
# 在你的电脑（同一局域网）上执行，扫描局域网设备
# macOS / Linux：
ping raspberrypi.local

# 如果上面无法找到，可以用以下命令扫描整个局域网段（把 192.168.1 换成你的网段）
nmap -sn 192.168.1.0/24 | grep -A 2 "Raspberry"
```

---

## 4. SSH 远程连接设置

```bash
# 用你的树莓派 IP 地址连接（把 192.168.1.100 替换成实际 IP）
# 用户名替换成你在烧录时设置的用户名
ssh 你的用户名@192.168.1.100

# 首次连接会提示是否信任主机，输入 yes 回车
# 然后输入密码（烧录时设置的密码）
```

### 建议：设置固定 IP 地址（避免 IP 变动）

```bash
# 在树莓派上编辑网络配置
sudo nano /etc/dhcpcd.conf

# 在文件末尾添加以下内容（根据你的实际网络修改）：
# interface eth0          # 有线网卡
# static ip_address=192.168.1.200/24   # 想要固定的 IP
# static routers=192.168.1.1           # 路由器 IP（网关）
# static domain_name_servers=8.8.8.8   # DNS 服务器

# 保存（Ctrl+O 回车）退出（Ctrl+X）后重启网络
sudo systemctl restart dhcpcd
```

---

## 5. 安装运行环境依赖

登录树莓派后，执行以下命令安装所有依赖：

```bash
# 更新系统软件包列表和已安装软件
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y git curl wget vim

# 安装 Node.js（使用 NodeSource 官方脚本，安装 v20 LTS 版本）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 验证 Node.js 和 npm 安装成功
node -v    # 应显示 v20.x.x
npm -v     # 应显示 npm 版本号

# 安装 Python 3 和 pip（GPIO 控制脚本需要）
sudo apt install -y python3 python3-pip python3-venv

# 验证 Python 安装
python3 --version   # 应显示 Python 3.x.x

# 安装 GPIO 库（用于物理按键控制，可选）
sudo apt install -y python3-rpi.gpio
```

---

## 6. 拉取项目代码

```bash
# 进入用户主目录
cd ~

# 克隆你的 fork 仓库（把链接替换成你自己的仓库地址）
git clone https://github.com/zsy-smu/v2c-project.git

# 进入项目目录
cd v2c-project

# 查看项目文件结构
ls -la
```

---

## 7. 配置环境变量

```bash
# 进入项目目录
cd ~/v2c-project

# 复制环境变量模板文件
cp .env.example .env

# 用编辑器打开，按照注释填写你的实际配置
nano .env

# 保存（Ctrl+O 回车）退出（Ctrl+X）
```

> 详细的环境变量说明请查阅项目根目录的 `.env.example` 文件，每一项都有中文注释。

---

## 8. 启动后端服务

```bash
# 进入项目目录
cd ~/v2c-project

# 安装 Node.js 依赖（如果项目使用 Node.js）
npm install

# 测试手动启动（验证服务正常）
npm start
# 或者
node server.js

# 看到类似 "服务已在端口 3000 启动" 的输出说明成功
# 按 Ctrl+C 停止（后面改用 systemd 管理）
```

---

## 9. 配置开机自启（systemd）

```bash
# 复制 systemd 服务配置文件到系统目录
sudo cp ~/v2c-project/deploy/systemd/v2c-backend.service /etc/systemd/system/

# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable v2c-backend.service

# 立即启动服务
sudo systemctl start v2c-backend.service

# 查看服务运行状态
sudo systemctl status v2c-backend.service

# 如果看到 "active (running)" 字样，说明服务已成功运行
```

---

## 10. 局域网访问验证

```bash
# 在树莓派上查看服务是否在监听端口（默认 3000）
ss -tlnp | grep 3000

# 在同一局域网的电脑或手机浏览器中访问：
# http://树莓派IP:3000
# 例如：http://192.168.1.200:3000

# 快速验证脚本
~/v2c-project/scripts/check_service.sh
```

---

## 11. 常见问题排查

### 问题：SSH 连接超时或拒绝连接

```bash
# 确认树莓派 IP 正确
ping 树莓派IP

# 确认 SSH 服务已启动（在树莓派屏幕上执行）
sudo systemctl status ssh
sudo systemctl start ssh
```

### 问题：Node.js 依赖安装失败

```bash
# 清除缓存重试
npm cache clean --force
npm install
```

### 问题：服务启动失败

```bash
# 查看详细日志
sudo journalctl -u v2c-backend.service -n 50 --no-pager

# 检查端口是否被占用
sudo lsof -i :3000
```

### 问题：无法从其他设备访问

```bash
# 检查防火墙是否放行端口
sudo ufw status
sudo ufw allow 3000/tcp   # 放行 3000 端口
```

---

*文档版本：v1.0 | 最后更新：2026年4月 | 维护者：Zsy @ 上海海事大学*
