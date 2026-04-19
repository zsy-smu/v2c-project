# 树莓派部署指南（V2C Project）

> 本文档适用于将 V2C Project 后端服务部署到 **树莓派 4B / 5（推荐 4GB 及以上内存）** 的完整流程。
> 全程操作均在 Linux 终端下完成，适合中文用户直接照步骤复制执行。

---

## 目录

1. [硬件准备](#1-硬件准备)
2. [烧录系统镜像](#2-烧录系统镜像)
3. [首次启动与基础配置](#3-首次启动与基础配置)
4. [安装项目依赖](#4-安装项目依赖)
5. [拉取并配置项目代码](#5-拉取并配置项目代码)
6. [配置环境变量](#6-配置环境变量)
7. [设置 systemd 开机自启服务](#7-设置-systemd-开机自启服务)
8. [验证服务状态](#8-验证服务状态)
9. [可选：GPIO 按键演示](#9-可选gpio-按键演示)
10. [常见问题排查](#10-常见问题排查)

---

## 1. 硬件准备

| 配件 | 规格建议 | 备注 |
|------|----------|------|
| 树莓派主板 | 4B (4GB+) 或 5 (4GB+) | 推荐 8GB 版本 |
| MicroSD 卡 | 32GB+，Class 10 / A1 | 推荐 SanDisk Ultra |
| 电源适配器 | 官方 5V 3A（4B）/ 5V 5A（5代） | 稳定供电非常关键 |
| 散热外壳 | 带风扇（主动散热） | 长时间运行必备 |
| 网线 | 千兆以太网线 | 首次配置强烈推荐有线 |
| HDMI 线 | Micro-HDMI（4B）/ Mini-HDMI（5代） | 首次调试用 |
| USB 读卡器 | — | 用于在电脑上烧录镜像 |

---

## 2. 烧录系统镜像

### 2.1 下载 Raspberry Pi Imager

前往官网下载烧录工具（免费）：
- Windows / macOS / Ubuntu：https://www.raspberrypi.com/software/

### 2.2 选择系统镜像

推荐选择：
- **Raspberry Pi OS Lite（64-bit）**：无桌面，资源占用最少，适合服务器场景
- 如需图形界面调试，可选 **Raspberry Pi OS（64-bit）** Desktop 版本

### 2.3 写入镜像（推荐使用 Imager 内置 SSH 预配置）

在 Imager 的"高级选项"中：

1. ✅ 启用 SSH（选择"使用密码登录"或"仅公钥"）
2. ✅ 设置用户名和密码（例如：用户名 `pi`，密码自定义）
3. ✅ 配置 Wi-Fi（如果需要无线连接，填入 SSID 和密码）
4. ✅ 设置地区 / 时区（推荐：`Asia/Shanghai`）

写入完成后，将 SD 卡插入树莓派，接上电源和网线开机。

---

## 3. 首次启动与基础配置

### 3.1 通过 SSH 登录

找到树莓派的局域网 IP（路由器后台或 `ping raspberrypi.local`）：

```bash
# 从你的电脑 SSH 登录树莓派（替换 <树莓派IP>）
ssh pi@<树莓派IP>
# 例如：ssh pi@192.168.1.100
```

首次登录会提示确认指纹，输入 `yes` 后回车，再输入密码。

### 3.2 更新系统软件包

登录树莓派后，执行：

```bash
sudo apt update && sudo apt upgrade -y
```

> 说明：首次更新可能需要 5～15 分钟，请耐心等待。

### 3.3 配置固定 IP（推荐，方便长期访问）

```bash
# 查看当前网络接口名
ip addr

# 编辑 DHCP 配置（以太网 eth0 为例）
sudo nano /etc/dhcpcd.conf
```

在文件末尾追加如下内容（根据你的路由器网段调整）：

```
# 树莓派固定 IP 配置
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8
```

保存（Ctrl+O，回车），退出（Ctrl+X），然后重启网络：

```bash
sudo systemctl restart dhcpcd
```

---

## 4. 安装项目依赖

### 4.1 安装 Node.js（如项目为 Node.js 技术栈）

```bash
# 方法一：使用 NodeSource 官方脚本（推荐）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 验证安装版本
node -v
npm -v
```

### 4.2 安装 Python 3 及 pip（如项目包含 Python 脚本）

```bash
# 树莓派 OS 已自带 Python 3，仅需安装 pip
sudo apt install -y python3-pip python3-venv

# 验证版本
python3 --version
pip3 --version
```

### 4.3 安装 Git

```bash
sudo apt install -y git
git --version
```

### 4.4 安装其他常用工具

```bash
sudo apt install -y curl wget unzip build-essential
```

---

## 5. 拉取并配置项目代码

```bash
# 进入你的工作目录
cd ~

# 克隆项目代码（替换为你的仓库地址）
git clone https://github.com/zsy-smu/v2c-project.git

# 进入项目目录
cd v2c-project

# 安装 Node.js 依赖（如果有 package.json）
# npm install

# 安装 Python 依赖（如果有 requirements.txt）
# pip3 install -r requirements.txt
```

---

## 6. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑环境变量（根据你的实际情况填写）
nano .env
```

> 详细的环境变量说明请参考 `.env.example` 文件中的中文注释。

---

## 7. 设置 systemd 开机自启服务

将 systemd 服务配置文件复制到系统目录：

```bash
# 复制服务文件
sudo cp systemd/v2c-project.service /etc/systemd/system/

# 重新加载 systemd 守护进程
sudo systemctl daemon-reload

# 启动服务
sudo systemctl start v2c-project

# 设置开机自动启动
sudo systemctl enable v2c-project

# 查看服务状态
sudo systemctl status v2c-project
```

---

## 8. 验证服务状态

```bash
# 方法一：运行一键检测脚本
bash scripts/check.sh

# 方法二：手动查看服务日志
sudo journalctl -u v2c-project -f --no-pager

# 方法三：查看最近 50 行日志
sudo journalctl -u v2c-project -n 50 --no-pager
```

---

## 9. 可选：GPIO 按键演示

> 如果你希望通过物理按钮触发服务接口，以增强演示效果，可以运行 GPIO 演示脚本。

**接线方式（以树莓派 4B 为例）：**

```
按键一端 → GPIO 17（引脚 11）
按键另一端 → GND（引脚 9）
```

```bash
# 安装 GPIO 依赖库
pip3 install RPi.GPIO requests

# 运行 GPIO 按键演示（按 Ctrl+C 退出）
python3 scripts/gpio_demo.py
```

演示效果：按下物理按钮后，脚本将向本地服务发送一次 HTTP 请求，模拟"物理触发"交互。

---

## 10. 常见问题排查

### Q: SSH 连接超时或拒绝连接？

1. 确认树莓派已开机（电源指示灯亮红色，活动指示灯闪烁绿色）
2. 确认 Imager 烧录时已启用 SSH
3. 使用路由器后台确认树莓派的实际 IP 地址
4. 检查防火墙：`sudo ufw status`

### Q: npm install 报错 EACCES 权限不足？

```bash
# 修复 npm 全局安装权限问题
mkdir ~/.npm-global
npm config set prefix '~/.npm-global'
echo 'export PATH=~/.npm-global/bin:$PATH' >> ~/.bashrc
source ~/.bashrc
```

### Q: 服务启动失败如何调试？

```bash
# 查看服务状态和最近错误
sudo systemctl status v2c-project
sudo journalctl -u v2c-project -n 100 --no-pager
```

### Q: 如何更新项目代码？

```bash
cd ~/v2c-project
git pull origin main
# 重启服务
sudo systemctl restart v2c-project
```

### Q: 如何完全停止并禁用服务？

```bash
sudo systemctl stop v2c-project
sudo systemctl disable v2c-project
```

---

> 如有问题，欢迎在 GitHub Issues 区反馈：https://github.com/zsy-smu/v2c-project/issues
