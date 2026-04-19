# V2C Project — Jetson Orin Nano 实体部署手册

> 本文档面向中文开发者，提供在 **NVIDIA Jetson Orin Nano Super 8G + JetPack 6.1** 上
> 通过 MobaXterm SSH 完整部署 V2C Project 后端服务的全流程指引。
> 所有命令均可直接复制执行，所有说明均使用中文。

---

## 目录

1. [硬件与软件准备](#1-硬件与软件准备)
2. [MobaXterm SSH 连接 Jetson](#2-mobaxterm-ssh-连接-jetson)
3. [基础环境检查](#3-基础环境检查)
4. [安装运行环境依赖](#4-安装运行环境依赖)
5. [拉取项目代码](#5-拉取项目代码)
6. [使用一键部署脚本（推荐）](#6-使用一键部署脚本推荐)
7. [手动配置环境变量](#7-手动配置环境变量)
8. [启动后端服务](#8-启动后端服务)
9. [配置开机自启（systemd）](#9-配置开机自启systemd)
10. [局域网访问验证](#10-局域网访问验证)
11. [GPIO 物理按键配置（可选）](#11-gpio-物理按键配置可选)
12. [常见问题排查](#12-常见问题排查)

---

## 1. 硬件与软件准备

| 项目 | 规格 | 说明 |
|------|------|------|
| 开发板 | Jetson Orin Nano Super 8G | 本文档以此型号为基准 |
| 系统 | JetPack 6.1（Ubuntu 22.04） | JetPack 5.x 步骤基本相同 |
| 远程工具 | MobaXterm | Windows 端推荐，支持 SSH + 文件传输 |
| 网络 | 与 Jetson 同一局域网 | 有线或 WiFi 均可 |
| 物理按键（可选） | 轻触开关 + 杜邦线 | GPIO 演示交互用 |

---

## 2. MobaXterm SSH 连接 Jetson

1. 打开 MobaXterm，点击 **Session → SSH**
2. **Remote host** 填写 Jetson 的局域网 IP（如 `192.168.1.100`）
3. **Username** 填 `nvidia`（JetPack 默认用户名）
4. 点击 OK，输入密码（默认为 `nvidia`，建议首次登录后修改）

```bash
# 登录后先确认 IP 地址（在 Jetson 终端执行）
hostname -I
```

### 建议：设置固定 IP（避免 IP 每次变化）

```bash
# 查看当前网卡名称
ip link show

# 编辑 netplan 配置（以 eth0 为例，实际网卡名以上面输出为准）
sudo nano /etc/netplan/01-netcfg.yaml
```

填写以下内容（根据实际网络修改 IP 和网关）：

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.1.100/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [8.8.8.8, 114.114.114.114]
```

```bash
# 应用配置
sudo netplan apply
```

---

## 3. 基础环境检查

登录 Jetson 后，先确认环境正常：

```bash
# 查看系统信息
uname -a
cat /etc/os-release

# 查看 JetPack 版本
head -1 /etc/nv_tegra_release

# 检查 Python 版本（JetPack 6.1 预装 Python 3.10）
python3 --version

# 检查 Node.js 是否已安装
node -v || echo "Node.js 未安装，下一步将安装"
npm -v || true
```

---

## 4. 安装运行环境依赖

```bash
# 更新系统软件包
sudo apt update && sudo apt upgrade -y

# 安装基础工具
sudo apt install -y git curl wget vim build-essential ca-certificates

# 安装 Node.js v20 LTS（使用 NodeSource 官方脚本）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# 验证安装
node -v    # 应显示 v20.x.x
npm -v

# 安装 Python pip 和虚拟环境（JetPack 通常已预装 python3）
sudo apt install -y python3-pip python3-venv

# 安装 Jetson GPIO 库（API 与 RPi.GPIO 完全兼容）
sudo pip3 install Jetson.GPIO

# 将当前用户加入 gpio 用户组（避免每次使用 sudo）
sudo groupadd -f -r gpio
sudo usermod -a -G gpio $USER
# 注意：需重新登录 SSH 后生效
```

---

## 5. 拉取项目代码

```bash
# 进入用户主目录
cd ~

# 克隆仓库
git clone https://github.com/zsy-smu/v2c-project.git

# 进入项目目录
cd v2c-project

# 查看项目文件结构
ls -la
```

---

## 6. 使用一键部署脚本（推荐）

项目提供了专为 Jetson 编写的一键部署脚本，**自动完成**环境安装、依赖配置、systemd 服务注册全流程：

```bash
# 给脚本添加执行权限
chmod +x scripts/setup_jetson.sh

# 运行 Jetson 一键部署脚本
./scripts/setup_jetson.sh
```

脚本会自动完成以下操作：
- ✅ 系统更新
- ✅ 安装 Node.js / Python3 / Jetson.GPIO
- ✅ 安装项目依赖（npm install）
- ✅ 从模板创建 `.env` 配置文件
- ✅ 注册 systemd 开机自启服务
- ✅ 创建日志目录

> **脚本运行完成后，务必编辑 `.env` 文件填写实际配置（见第 7 步），然后重启服务。**

---

## 7. 手动配置环境变量

```bash
# 进入项目目录
cd ~/v2c-project

# 从模板创建（如未通过脚本创建）
cp .env.example .env

# 编辑配置文件
nano .env
```

**重点配置项说明：**

| 变量名 | 说明 | 示例值 |
|--------|------|--------|
| `PORT` | 后端服务端口 | `3000` |
| `NODE_ENV` | 运行环境 | `production` |
| `JETSON_DEVICE_IP` | 本机（Jetson）局域网 IP | `192.168.1.100` |
| `JETSON_DATA_PORT` | 视觉数据推送端口 | `9000` |
| `CONTROLLER_IP` | 控制端（MuJoCo/G1）IP | `192.168.1.60` |
| `CONTROLLER_PORT` | 控制端接收端口 | `8888` |
| `GPIO_ENABLE` | 是否启用 GPIO 按键 | `false` / `true` |

> 保存方法：`Ctrl+O` 回车保存，`Ctrl+X` 退出

---

## 8. 启动后端服务

```bash
cd ~/v2c-project

# 安装 Node.js 依赖（如未通过脚本安装）
npm install

# 手动测试启动（验证服务正常后再配置自启）
npm start
# 或
node server.js

# 看到类似 "服务已在端口 3000 启动" 的输出说明成功
# 按 Ctrl+C 停止（后面改用 systemd 管理）
```

---

## 9. 配置开机自启（systemd）

```bash
# 复制 systemd 服务配置文件（服务文件默认已适配 Jetson nvidia 用户）
sudo cp ~/v2c-project/deploy/systemd/v2c-backend.service /etc/systemd/system/

# 如果你的用户名不是 nvidia，需要修改服务文件中的用户名和路径：
# sudo sed -i "s/nvidia/$USER/g" /etc/systemd/system/v2c-backend.service

# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable v2c-backend.service

# 立即启动服务
sudo systemctl start v2c-backend.service

# 查看服务运行状态
sudo systemctl status v2c-backend.service

# 如果看到 "active (running)" 字样，说明服务已成功运行 ✓
```

---

## 10. 局域网访问验证

```bash
# 在 Jetson 上查看服务是否监听端口（默认 3000）
ss -tlnp | grep 3000

# 查看 Jetson 的局域网 IP
hostname -I

# 在同一局域网的电脑或手机浏览器中访问：
# http://Jetson的IP:3000
# 例如：http://192.168.1.100:3000

# 使用检查脚本快速验证
./scripts/check_service.sh
```

---

## 11. GPIO 物理按键配置（可选）

Jetson Orin Nano 的 40 针 GPIO 接口与树莓派布局相同，接线方式一致。

### 接线方式

```
Jetson 40 针接口            按钮
─────────────────────────────────────
物理引脚 11  (GPIO 17) ──── 按钮引脚 A
物理引脚  6  (GND)    ──── 按钮引脚 B
─────────────────────────────────────
```

### 启用步骤

```bash
# 1. 编辑 .env 文件，开启 GPIO 功能
nano ~/v2c-project/.env
# 将 GPIO_ENABLE=false 改为 GPIO_ENABLE=true
# 保存退出

# 2. 确认已安装 Jetson.GPIO
python3 -c "import Jetson.GPIO; print('Jetson.GPIO 可用 ✓')"

# 3. 运行 GPIO 监听程序（前台测试）
python3 ~/v2c-project/gpio_demo/gpio_button.py

# 4. 按下物理按键，观察输出：
# 2026年04月19日 10:00:00 [INFO] 检测到按键按下（引脚 GPIO 17）
# 2026年04月19日 10:00:00 [INFO] ✓ 按键触发成功！接口返回状态码：200
```

---

## 12. 常见问题排查

### 问题：SSH 连接失败

```bash
# 确认 Jetson 已开机并联网
# 在 Jetson 屏幕（或串口）上确认 IP：
hostname -I

# 确认 SSH 服务运行中
sudo systemctl status ssh
sudo systemctl start ssh
```

### 问题：Node.js 安装失败

```bash
# 清除缓存重试
npm cache clean --force
npm install
```

### 问题：服务启动失败

```bash
# 查看详细错误日志
sudo journalctl -u v2c-backend.service -n 50 --no-pager

# 检查 .env 配置文件是否存在
ls -la ~/v2c-project/.env

# 检查端口是否被占用
sudo lsof -i :3000
```

### 问题：Jetson.GPIO 导入失败 / 需要 root

```bash
# 确认用户在 gpio 用户组中
groups $USER

# 若没有 gpio 组，重新添加
sudo groupadd -f -r gpio
sudo usermod -a -G gpio $USER
# 重新登录 SSH 后生效

# 如临时需要 sudo 运行
sudo python3 ~/v2c-project/gpio_demo/gpio_button.py
```

### 问题：无法从其他设备访问

```bash
# 检查防火墙是否放行端口
sudo ufw status
sudo ufw allow 3000/tcp   # 放行 3000 端口
sudo ufw reload
```

### 问题：重启后服务未自启

```bash
# 确认服务已 enable
sudo systemctl is-enabled v2c-backend

# 若显示 disabled，重新启用
sudo systemctl enable v2c-backend.service
```

---

*文档版本：v1.0 | 最后更新：2026年4月 | 适用设备：Jetson Orin Nano Super 8G + JetPack 6.1 | 维护者：Zsy @ 上海海事大学*
