# V2C Project — Jetson Orin Nano 实体部署手册

> 本文档面向中文开发者，提供在 **NVIDIA Jetson Orin Nano Super 8G（JetPack 6.1）** 上完整部署  
> V2C Project 后端服务的全流程指引。所有命令均可直接复制执行，所有说明均使用中文。
>
> 连接方式：**MobaXterm SSH**

---

## 目录

1. [硬件与环境准备](#1-硬件与环境准备)
2. [MobaXterm SSH 连接](#2-mobaxterm-ssh-连接)
3. [基础系统配置](#3-基础系统配置)
4. [安装运行环境依赖](#4-安装运行环境依赖)
5. [拉取项目代码](#5-拉取项目代码)
6. [配置环境变量](#6-配置环境变量)
7. [启动后端服务](#7-启动后端服务)
8. [配置开机自启（systemd）](#8-配置开机自启systemd)
9. [局域网访问验证](#9-局域网访问验证)
10. [GPIO 按键功能（可选）](#10-gpio-按键功能可选)
11. [常见问题排查](#11-常见问题排查)

---

## 1. 硬件与环境准备

| 硬件 / 软件 | 规格 | 备注 |
|---|---|---|
| Jetson Orin Nano Super 8G | NVIDIA 官方模组 | 本文档专为此型号编写 |
| JetPack 版本 | **6.1** | 基于 Ubuntu 22.04 LTS（arm64） |
| 电源 | 官方 DC 19V 5A 电源 | 劣质电源会导致随机重启 |
| 存储 | NVMe SSD（推荐 64GB+）或 SD 卡 | NVMe 读写速度更快 |
| 网络 | 局域网连接（网线或 WiFi） | 首次配置推荐有线连接 |
| 主机 | 安装了 **MobaXterm** 的 Windows 电脑 | 用于 SSH 远程访问 |

> **前提**：Jetson 设备已完成 JetPack 6.1 初始化烧录，可正常开机登录。  
> 默认用户名通常为 `nvidia`，首次登录时需要设置密码。

---

## 2. MobaXterm SSH 连接

### 第一步：确认 Jetson 的 IP 地址

在 Jetson 上连接显示器和键盘，或通过路由器后台查看已连接设备，找到 Jetson 的局域网 IP：

```bash
# 在 Jetson 上查看局域网 IP（选择 eth0 有线或 wlan0 无线）
ip addr show
# 或
hostname -I
```

### 第二步：MobaXterm 建立 SSH 连接

1. 打开 **MobaXterm**
2. 点击顶部菜单 `Session` → `SSH`
3. 在 **Remote host** 填写 Jetson 的局域网 IP，例如 `192.168.1.50`
4. 勾选 **Specify username**，填写 `nvidia`
5. 点击 `OK`，首次连接输入密码后即可进入终端

### 建议：设置固定 IP 地址（避免 IP 变动）

```bash
# 在 Jetson 上，创建 NetworkManager 静态 IP 配置
# 将 <你的IP>、<你的网关>、<接口名> 替换成实际值
sudo nmcli con mod "有线连接 1" \
    ipv4.addresses 192.168.1.50/24 \
    ipv4.gateway 192.168.1.1 \
    ipv4.dns "8.8.8.8 114.114.114.114" \
    ipv4.method manual

# 重新激活连接使配置生效
sudo nmcli con up "有线连接 1"

# 验证 IP 已更改
ip addr show eth0
```

> **说明**：JetPack 6.1 使用 NetworkManager 管理网络，与树莓派的 dhcpcd 不同。  
> 如果接口名不是 `有线连接 1`，可用 `nmcli con show` 查看当前连接名称。

---

## 3. 基础系统配置

SSH 登录 Jetson 后，先做基础环境检查和配置：

```bash
# 查看系统版本信息
uname -a
cat /etc/os-release

# 查看 JetPack 版本
cat /etc/nv_tegra_release 2>/dev/null || dpkg -l | grep -i jetpack

# 查看 GPU 信息（Jetson 专用）
nvidia-smi 2>/dev/null || tegrastats --interval 1000 &

# 更新系统软件包
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y git curl wget vim net-tools
```

---

## 4. 安装运行环境依赖

### 安装 Node.js（后端服务运行时）

```bash
# 安装 Node.js v20 LTS（通过 NodeSource 官方脚本）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 验证安装成功
node -v    # 应显示 v20.x.x
npm -v     # 应显示 npm 版本号
```

### 安装 Python 3 环境（GPIO 脚本依赖）

JetPack 6.1 已预装 Python 3.10，只需安装必要的额外库：

```bash
# 安装 pip 和虚拟环境工具
sudo apt install -y python3-pip python3-venv

# 验证 Python 版本
python3 --version   # 应显示 Python 3.10.x

# 安装 Jetson GPIO 库（Jetson 专用，替代树莓派的 RPi.GPIO）
sudo pip3 install Jetson.GPIO

# 将当前用户加入 GPIO 用户组（避免每次都需要 sudo）
sudo usermod -aG gpio $USER

# 加入 i2c 和 spi 用户组（如需使用其他外设）
sudo usermod -aG i2c $USER
sudo usermod -aG spi $USER

# ⚠️ 重要：组权限更改需要重新登录 SSH 才能生效
echo "请重新连接 SSH 使 GPIO 用户组权限生效"
```

> **Jetson vs 树莓派 GPIO 说明**：
> - 树莓派使用 `RPi.GPIO` 库，Jetson 使用 `Jetson.GPIO`
> - 两个库的 API 接口基本相同，代码迁移成本极低
> - 本项目的 `gpio_demo/gpio_button.py` 已自动检测并选择正确的库

---

## 5. 拉取项目代码

```bash
# 进入用户主目录
cd ~

# 克隆项目仓库（替换成你自己的仓库地址）
git clone https://github.com/zsy-smu/v2c-project.git

# 进入项目目录
cd v2c-project

# 查看项目文件结构
ls -la
```

---

## 6. 配置环境变量

```bash
# 进入项目目录
cd ~/v2c-project

# 复制环境变量模板文件
cp .env.example .env

# 用编辑器打开，按照注释填写你的实际配置
nano .env

# 保存（Ctrl+O 回车）退出（Ctrl+X）
```

**Jetson 部署时重点修改以下配置：**

```bash
# 基础服务配置
服务端口=3000
运行环境=production

# Jetson 本机视觉推理地址（Jetson 既是视觉端也是服务运行端时填 127.0.0.1）
Jetson设备地址=127.0.0.1
Jetson数据端口=9000

# 控制端地址（MuJoCo / G1 机器人运行在其他设备时填写对应 IP）
控制端地址=192.168.1.60
控制端口=8888

# GPIO 按键（可选，默认关闭）
启用GPIO按键=false
```

---

## 7. 启动后端服务

```bash
# 进入项目目录
cd ~/v2c-project

# 安装 Node.js 依赖
npm install

# 手动测试启动（验证服务正常）
npm start
# 或者
node server.js

# 看到类似 "服务已在端口 3000 启动" 的输出说明成功
# 按 Ctrl+C 停止（后面改用 systemd 管理）
```

---

## 8. 配置开机自启（systemd）

### 方式一：使用一键部署脚本（推荐）

```bash
# 赋予脚本执行权限
chmod +x ~/v2c-project/scripts/setup_jetson.sh

# 运行 Jetson 专用一键部署脚本
~/v2c-project/scripts/setup_jetson.sh
```

### 方式二：手动配置 systemd

```bash
# 将 systemd 服务配置文件中的用户名替换为当前用户（nvidia）
sudo sed "s/User=pi/User=$USER/g; s/Group=pi/Group=$USER/g; s|/home/pi|$HOME|g" \
    ~/v2c-project/deploy/systemd/v2c-backend.service \
    > /tmp/v2c-backend.service

# 复制到 systemd 服务目录
sudo cp /tmp/v2c-backend.service /etc/systemd/system/v2c-backend.service

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

## 9. 局域网访问验证

```bash
# 在 Jetson 上查看服务是否在监听端口（默认 3000）
ss -tlnp | grep 3000

# 查看 Jetson 的局域网 IP
hostname -I | awk '{print $1}'

# 在同一局域网的电脑或手机浏览器中访问：
# http://Jetson的IP:3000
# 例如：http://192.168.1.50:3000

# 在 MobaXterm 终端中快速验证
~/v2c-project/scripts/check_service.sh
```

---

## 10. GPIO 按键功能（可选）

> 此功能默认关闭，需显式开启。开启前请确认已按接线图完成硬件连接。

### Jetson Orin Nano GPIO 引脚对照（BCM 编号）

```
Jetson Orin Nano 40 针接口（部分）：
      3.3V [1]  [2] 5V
  GPIO 2  [3]  [4] 5V
  GPIO 3  [5]  [6] GND    ← 接按钮另一端
  GPIO 4  [7]  [8] GPIO 14
       GND [9] [10] GPIO 15
  GPIO 17 [11] [12] GPIO 18  ← 接按钮一端（默认引脚）
```

> **注意**：Jetson Orin Nano 的物理引脚布局与树莓派相同（40 针标准接口），  
> BCM 引脚编号也兼容，但部分引脚功能有差异，请以 Jetson 官方 pinout 为准。

### 开启 GPIO 功能步骤

```bash
# 1. 编辑 .env 文件
nano ~/v2c-project/.env

# 将以下行改为 true
启用GPIO按键=true

# 2. 重启 GPIO 监听程序（或重启服务）
sudo systemctl restart v2c-backend

# 3. 手动测试 GPIO 监听（独立运行）
python3 ~/v2c-project/gpio_demo/gpio_button.py
```

---

## 11. 常见问题排查

### 问题：SSH 连接超时或拒绝连接

```bash
# 确认 Jetson 开机并获取 IP 地址
# 在路由器后台查看已连接设备，或将 Jetson 接显示器执行：
hostname -I

# 确认 SSH 服务已启动
sudo systemctl status ssh
sudo systemctl start ssh
sudo systemctl enable ssh
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
# 或
sudo ss -tlnp | grep 3000
```

### 问题：GPIO 权限不足

```bash
# 确认用户已在 gpio 用户组
groups $USER | grep gpio

# 如果没有，重新添加并重新登录
sudo usermod -aG gpio $USER
# 重新连接 SSH

# 也可临时用 sudo 运行
sudo python3 ~/v2c-project/gpio_demo/gpio_button.py
```

### 问题：Jetson.GPIO 未安装

```bash
# 重新安装
sudo pip3 install Jetson.GPIO

# 或从源码安装
git clone https://github.com/NVIDIA/jetson-gpio.git
cd jetson-gpio
sudo python3 setup.py install
```

### 问题：无法从其他设备访问

```bash
# 检查防火墙状态
sudo ufw status

# 放行 3000 端口（如果防火墙已启用）
sudo ufw allow 3000/tcp
```

### 问题：tegrastats 无法查看温度

```bash
# 查看 Jetson 温度（JetPack 6.1）
cat /sys/class/thermal/thermal_zone*/temp | awk '{printf "%.1f°C\n", $1/1000}'

# 或使用 jetson-stats 工具
sudo pip3 install jetson-stats
sudo jtop
```

---

*文档版本：v1.0 | 最后更新：2026年4月 | 维护者：Zsy @ 上海海事大学*  
*适用设备：NVIDIA Jetson Orin Nano Super 8G + JetPack 6.1*
