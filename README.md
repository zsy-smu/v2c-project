# V2C Project — 视觉与控制协同系统

> V2C（Vision to Control）是一个面向边缘 AI 设备的视觉感知与机器人控制协同系统。  
> 视觉端（Jetson）实时捕获目标信息，通过局域网传输给后端服务，后端再将控制指令下发给机器人执行端。

---

## 项目结构

```
v2c-project/
├── docs/                        # 部署与使用文档
│   ├── jetson-deploy.md         # Jetson 部署手册（推荐）
│   └── raspberry-pi-deploy.md  # 树莓派部署手册（旧方案）
├── scripts/                     # 自动化脚本
│   ├── setup_jetson.sh          # Jetson 一键部署脚本
│   ├── setup_pi.sh              # 树莓派一键部署脚本
│   └── check_service.sh         # 服务状态检查脚本
├── deploy/
│   └── systemd/
│       ├── v2c-backend-jetson.service  # Jetson systemd 服务模板
│       └── v2c-backend.service         # 通用 systemd 服务模板
├── gpio_demo/                   # GPIO 按键交互示例
├── demo_runbook.md              # 演示手册（全流程操作指引）
└── .env.example                 # 环境变量配置模板
```

---

## ⚡ Jetson 快速开始

> **推荐部署平台**：NVIDIA Jetson Orin Nano Super 8G，系统 JetPack 6.1  
> 通过 MobaXterm 或 SSH 连接到 Jetson 后，执行以下命令即可完成部署。

### 第一步：克隆项目

```bash
cd ~
git clone https://github.com/zsy-smu/v2c-project.git
cd v2c-project
```

### 第二步：一键部署（推荐）

```bash
chmod +x scripts/setup_jetson.sh
./scripts/setup_jetson.sh
```

脚本会自动完成：系统依赖安装、Node.js 环境配置、项目依赖安装、环境变量初始化、systemd 服务注册与启动。

### 第三步：填写配置文件

```bash
# 脚本执行完成后，编辑 .env 文件填写实际配置
nano ~/.../v2c-project/.env
```

### 第四步：验证部署

```bash
# 检查服务状态
./scripts/check_service.sh

# 或者直接查看 systemd 状态
sudo systemctl status v2c-backend
```

### 常用管理命令

| 操作 | 命令 |
|------|------|
| 查看服务状态 | `sudo systemctl status v2c-backend` |
| 启动服务 | `sudo systemctl start v2c-backend` |
| 停止服务 | `sudo systemctl stop v2c-backend` |
| 重启服务 | `sudo systemctl restart v2c-backend` |
| 查看实时日志 | `sudo journalctl -u v2c-backend -f` |
| 查看最近日志 | `sudo journalctl -u v2c-backend -n 50 --no-pager` |

> 📖 完整部署文档请查阅 [docs/jetson-deploy.md](docs/jetson-deploy.md)

---

## 演示手册

现场演示请参考 [demo_runbook.md](demo_runbook.md)，包含从开机到演示结束的完整中文操作步骤。

---

## 技术架构

```
Jetson Orin Nano（视觉推理）
    ↓ 目标坐标（UDP/TCP，端口 9000）
后端服务（Node.js，端口 3000）
    ↓ 控制指令
机器人控制端（MuJoCo / G1，端口 8888）
```

---

*维护者：Zsy @ 上海海事大学 | 目标平台：Jetson Orin Nano Super 8G + JetPack 6.1*
