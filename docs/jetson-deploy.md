# V2C Project — Jetson 实体部署手册

> 本文档面向 **NVIDIA Jetson Orin Nano Super 8G + JetPack 6.1** 平台，  
> 提供从零开始完整部署 V2C Project 后端服务的全流程中文指引。  
> 所有命令均可直接复制执行，通过 MobaXterm 或任意 SSH 客户端操作。

---

## 目录

1. [硬件与系统确认](#1-硬件与系统确认)
2. [MobaXterm 连接方法](#2-mobaxterm-连接方法)
3. [安装系统依赖](#3-安装系统依赖)
4. [安装-nodejs-运行环境](#4-安装-nodejs-运行环境)
5. [拉取项目代码](#5-拉取项目代码)
6. [配置环境变量](#6-配置环境变量)
7. [手动启动验证](#7-手动启动验证)
8. [配置开机自启（systemd）](#8-配置开机自启systemd)
9. [局域网访问验证](#9-局域网访问验证)
10. [常见问题排查](#10-常见问题排查)
11. [附：Jetson 与树莓派差异说明](#11-附jetson-与树莓派差异说明)

---

## 1. 硬件与系统确认

在开始之前，请确认你的设备信息与以下一致：

| 项目 | 预期值 |
|------|--------|
| 设备型号 | NVIDIA Jetson Orin Nano Super 8G |
| 系统版本 | JetPack 6.1（基于 Ubuntu 22.04 LTS，aarch64） |
| 默认用户名 | `nvidia` |
| 连接方式 | MobaXterm SSH / 有线以太网 |

### 登录后先做系统信息确认

```bash
# 查看操作系统版本（应显示 Ubuntu 22.04）
cat /etc/os-release

# 查看内核和架构（应显示 aarch64）
uname -a

# 查看 JetPack 版本
cat /etc/nv_tegra_release 2>/dev/null || dpkg -l | grep -i jetpack

# 查看当前用户名
whoami

# 查看 Jetson 局域网 IP 地址（记录下来，后续访问用）
hostname -I
```

---

## 2. MobaXterm 连接方法

1. 打开 MobaXterm
2. 点击左上角「Session」→「SSH」
3. 填写以下信息：
   - **Remote host**：Jetson 的局域网 IP（如 `192.168.1.50`）
   - **Username**：`nvidia`
   - **Port**：`22`
4. 点击「OK」，首次连接输入密码（默认密码 `nvidia`，建议上线前修改）
5. 连接成功后即可在终端里执行以下所有命令

> **如何找到 Jetson 的 IP？**  
> - 方法一：连接显示器后登录，执行 `hostname -I`  
> - 方法二：路由器后台查看已连接设备列表  
> - 方法三：同局域网电脑执行 `nmap -sn 192.168.1.0/24`（把网段替换成你的实际网段）

---

## 3. 安装系统依赖

```bash
# 更新软件包列表（首次部署必须执行）
sudo apt update

# 升级已安装的软件包（可选，但建议执行）
sudo apt upgrade -y

# 安装基础工具
sudo apt install -y git curl wget vim build-essential ca-certificates

# 安装 Python 3 及相关工具（Jetson.GPIO 等依赖）
sudo apt install -y python3 python3-pip python3-venv

# 验证安装
python3 --version    # 应显示 Python 3.10.x 或以上
git --version        # 应显示 git 版本号
```

---

## 4. 安装 Node.js 运行环境

JetPack 6.1 基于 Ubuntu 22.04，可以直接使用 NodeSource 官方脚本安装 Node.js 20 LTS：

```bash
# 下载并执行 NodeSource 安装脚本（安装 Node.js 20 LTS）
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# 安装 Node.js
sudo apt install -y nodejs

# 验证安装成功
node -v    # 应显示 v20.x.x
npm -v     # 应显示 npm 版本号（10.x 以上）
```

> **注意**：如果 `curl` 访问外网失败，可以尝试先设置国内镜像源，或使用以下备用方案：
> ```bash
> # 备用方案：使用 nvm 安装 Node.js
> curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
> source ~/.bashrc
> nvm install 20
> nvm use 20
> ```

---

## 5. 拉取项目代码

```bash
# 进入用户主目录
cd ~

# 克隆项目仓库
git clone https://github.com/zsy-smu/v2c-project.git

# 进入项目目录
cd v2c-project

# 查看项目文件结构，确认克隆成功
ls -la

# 安装 Node.js 项目依赖
npm install

# 如果项目有 Python 依赖
# pip3 install -r requirements.txt
```

---

## 6. 配置环境变量

```bash
# 进入项目目录
cd ~/v2c-project

# 从模板创建 .env 文件
cp .env.example .env

# 用编辑器打开，按照注释填写你的实际配置
nano .env
```

### 重点配置项说明

```bash
# 服务端口（默认 3000，局域网通过 http://Jetson的IP:3000 访问）
服务端口=3000

# 运行环境（Jetson 实体部署填 production）
运行环境=production

# Jetson 本机 IP（视觉推理端地址，如果视觉和后端在同一台 Jetson，填 127.0.0.1）
Jetson设备地址=127.0.0.1

# 控制端地址（MuJoCo / G1 机器人控制端的 IP）
控制端地址=192.168.1.60

# 日志文件路径（Jetson 上改为 nvidia 用户目录）
日志文件路径=/home/nvidia/v2c-project/logs/app.log
```

> 保存方法：`Ctrl+O` → 回车确认 → `Ctrl+X` 退出

---

## 7. 手动启动验证

在配置 systemd 自启之前，先手动启动确认服务正常：

```bash
# 进入项目目录
cd ~/v2c-project

# 手动启动（选择适合你项目的启动命令）
npm start
# 或者
npm run dev
# 或者（如果是纯 Node 脚本）
node server.js

# 看到类似 "服务已在端口 3000 启动" 或 "listening on port 3000" 的输出说明成功
# 按 Ctrl+C 停止（后面改用 systemd 管理）
```

在 MobaXterm 中新开一个标签页（或另开 SSH 连接），测试接口连通性：

```bash
# 测试本机 HTTP 接口（在 Jetson 上执行）
curl -s http://127.0.0.1:3000
# 或者测试健康检查接口
curl -s http://127.0.0.1:3000/api/health

# 查看端口监听状态
ss -tlnp | grep 3000
```

---

## 8. 配置开机自启（systemd）

### 方法一：使用一键脚本（推荐）

```bash
cd ~/v2c-project
chmod +x scripts/setup_jetson.sh
./scripts/setup_jetson.sh
```

### 方法二：手动配置

```bash
# 将 Jetson 专用 systemd 服务文件复制到系统目录
# 脚本会自动将 User/WorkingDirectory 中的占位符替换为当前用户名（nvidia）
sudo sed "s/User=nvidia/User=$(whoami)/g; s|/home/nvidia|/home/$(whoami)|g" \
    ~/v2c-project/deploy/systemd/v2c-backend-jetson.service \
    > /tmp/v2c-backend.service

sudo cp /tmp/v2c-backend.service /etc/systemd/system/v2c-backend.service

# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用开机自启
sudo systemctl enable v2c-backend.service

# 立即启动服务
sudo systemctl start v2c-backend.service

# 查看服务运行状态（看到 active (running) 说明成功）
sudo systemctl status v2c-backend.service --no-pager
```

### 服务管理常用命令

```bash
# 查看服务状态
sudo systemctl status v2c-backend

# 查看实时日志（Ctrl+C 退出）
sudo journalctl -u v2c-backend -f

# 查看最近 50 条日志
sudo journalctl -u v2c-backend -n 50 --no-pager

# 重启服务（修改 .env 后需要重启）
sudo systemctl restart v2c-backend

# 停止服务
sudo systemctl stop v2c-backend

# 禁用开机自启
sudo systemctl disable v2c-backend
```

---

## 9. 局域网访问验证

```bash
# 查看 Jetson 局域网 IP（记录下来）
hostname -I

# 在 Jetson 上验证端口监听
ss -tlnp | grep 3000

# 在同一局域网的电脑或手机浏览器中访问：
# http://Jetson的IP:3000
# 例如：http://192.168.1.50:3000

# 使用一键检查脚本
cd ~/v2c-project
./scripts/check_service.sh
```

---

## 10. 常见问题排查

### 问题：SSH 连接超时或拒绝

```bash
# 确认 SSH 服务已开启（在 Jetson 屏幕或串口上执行）
sudo systemctl status ssh
sudo systemctl start ssh
sudo systemctl enable ssh
```

### 问题：Node.js 安装失败（网络问题）

```bash
# 方案一：配置 npm 国内镜像
npm config set registry https://registry.npmmirror.com

# 方案二：使用 nvm 离线安装（需提前下载安装包）
# 参考 https://github.com/nvm-sh/nvm
```

### 问题：npm install 失败

```bash
# 清除 npm 缓存后重试
npm cache clean --force
npm install

# 如果是权限问题
sudo chown -R $(whoami) ~/.npm
npm install
```

### 问题：服务启动失败

```bash
# 查看详细错误日志
sudo journalctl -u v2c-backend -n 100 --no-pager

# 检查 .env 文件是否存在且格式正确
cat ~/v2c-project/.env

# 检查端口是否被占用
sudo lsof -i :3000
# 或者
sudo fuser -n tcp 3000
```

### 问题：端口无法从外部访问

```bash
# 检查防火墙状态
sudo ufw status

# 如果防火墙已开启，放行服务端口
sudo ufw allow 3000/tcp

# JetPack 默认一般不启用 ufw，如果仍无法访问，检查路由器防火墙设置
```

### 问题：服务启动后自动停止

```bash
# 查看系统日志（包含 OOM 等系统级错误）
sudo journalctl -u v2c-backend -n 50 --no-pager
dmesg | tail -50

# 检查内存是否充足
free -h
```

### 问题：Jetson GPU/CUDA 相关错误

```bash
# 确认 CUDA 是否正常工作
nvcc --version
python3 -c "import torch; print(torch.cuda.is_available())"

# 查看 Jetson 硬件状态（需要 jetson-stats 工具）
sudo apt install -y python3-pip
sudo pip3 install jetson-stats
sudo jtop
```

---

## 11. 附：Jetson 与树莓派差异说明

| 对比项 | 树莓派 | Jetson Orin Nano |
|--------|--------|------------------|
| 默认用户名 | `pi` | `nvidia` |
| 主目录 | `/home/pi` | `/home/nvidia` |
| GPIO 库 | `RPi.GPIO` | `Jetson.GPIO` |
| 系统版本 | Raspberry Pi OS (Debian) | Ubuntu 22.04 (JetPack 6.1) |
| AI 加速 | 无 | CUDA + TensorRT（GPU 推理） |
| Node.js 安装 | 同 NodeSource 脚本 | 同 NodeSource 脚本（兼容 Ubuntu） |
| systemd 使用 | 完全相同 | 完全相同 |
| npm/pip 命令 | 完全相同 | 完全相同 |

### GPIO 库适配说明

如果项目中有使用 GPIO 引脚控制的代码，需要将 `RPi.GPIO` 替换为 `Jetson.GPIO`：

```bash
# 安装 Jetson GPIO 库
sudo pip3 install Jetson.GPIO

# 将当前用户加入 gpio 用户组（无需 sudo 操作 GPIO）
sudo groupadd -f -r gpio
sudo usermod -a -G gpio $USER
# 注销重新登录后生效
```

```python
# 树莓派写法（旧）：
import RPi.GPIO as GPIO

# Jetson 写法（新）：
import Jetson.GPIO as GPIO

# 其余 API 完全兼容，引脚编号对照 Jetson Orin Nano 的引脚图即可
```

---

*文档版本：v1.0 | 适用平台：Jetson Orin Nano Super 8G + JetPack 6.1 | 最后更新：2026年4月 | 维护者：Zsy @ 上海海事大学*
