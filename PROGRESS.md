# V2C Project — 进度报告

> 报告时间：2026年4月19日 | 维护者：Zsy @ 上海海事大学  
> 目标平台：NVIDIA Jetson Orin Nano Super 8G + JetPack 6.1

---

## 当前主分支状态

**主分支（main）最新合并提交：**

| # | 提交摘要 | 时间 |
|---|---------|------|
| 1 | Merge PR #7：解决树莓派 vs Jetson 部署冲突，以 Jetson 为主 | 2026-04-19 |
| 2 | refactor: 改善 GPIO 导入失败诊断输出 | 2026-04-19 |
| 3 | docs: 补充 Jetson 官方引脚图参考链接 | 2026-04-19 |
| 4 | fix: 保留 GPIO 导入异常以便诊断 | 2026-04-19 |
| 5 | fix: GPIO 与服务配置切换为 Jetson 优先 | 2026-04-19 |
| 6 | Merge PR #4：适配 Jetson Orin Nano Super 8G 部署 | 2026-04-19 |

---

## 已落地文件清单 ✅

### 部署基础设施（完整）

| 文件 | 说明 | 状态 |
|------|------|------|
| `README.md` | 中文项目说明 + Jetson 快速开始指引 | ✅ 完成 |
| `.env.example` | 环境变量配置模板（带完整中文注释） | ✅ 完成 |
| `docs/jetson-deploy.md` | Jetson 全流程部署手册（11 章节） | ✅ 完成 |
| `docs/raspberry-pi-deploy.md` | 树莓派部署手册（旧方案备用） | ✅ 完成 |
| `deploy/systemd/v2c-backend-jetson.service` | Jetson 专用 systemd 服务单元文件 | ✅ 完成 |
| `deploy/systemd/v2c-backend.service` | 通用 systemd 服务单元文件 | ✅ 完成 |
| `scripts/setup_jetson.sh` | Jetson 一键部署脚本（全中文注释，8 步骤） | ✅ 完成 |
| `scripts/setup_pi.sh` | 树莓派一键部署脚本 | ✅ 完成 |
| `scripts/check_service.sh` | 服务状态一键检查脚本 | ✅ 完成 |
| `demo_runbook.md` | 现场演示全流程操作手册 | ✅ 完成 |

### 功能代码

| 文件 | 说明 | 状态 |
|------|------|------|
| `gpio_demo/gpio_button.py` | GPIO 物理按键触发脚本（优先 Jetson.GPIO） | ✅ 完成 |
| `gpio_demo/README.md` | GPIO 接线与使用说明 | ✅ 完成 |
| `index.html` | 前端项目展示页（Tailwind CSS） | ✅ 完成 |
| `package.json` | Node.js 项目配置（定义 `npm start`） | ✅ 新增 |
| `server.js` | Node.js 后端主入口（HTTP + UDP 双协议） | ✅ 新增 |

---

## 后端服务接口（server.js）

| 接口 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 返回前端展示页（index.html） |
| `/api/health` | GET | 健康检查，返回运行状态、运行时长、最新视觉数据 |
| `/api/status` | GET | 服务状态（触发次数、最新视觉数据） |
| `/api/trigger` | POST | GPIO 按键触发接口 |
| `/api/vision` | POST | 视觉数据上报（HTTP 备用，主路径为 UDP） |
| UDP `9000` | — | 接收视觉端目标坐标（JSON 格式） |

---

## 数据流架构

```
Jetson 视觉端（YOLO 推理）
    ↓ UDP 端口 9000（目标坐标 JSON）
后端服务（server.js，HTTP 端口 3000）
    ↓ TCP 控制指令
机器人控制端（MuJoCo / G1，端口 8888）
```

---

## 未完成事项 / 待扩展 ⚠️

| 事项 | 优先级 | 说明 |
|------|--------|------|
| 视觉端推理代码 | 🔴 高 | YOLO 推理脚本尚未落地（需 Python + ultralytics/YOLO 实现） |
| 控制端指令下发 | 🔴 高 | `server.js` 目前仅接收视觉数据，尚未实现向控制端发送 TCP 指令 |
| `requirements.txt` | 🟡 中 | Python 依赖列表未创建（GPIO、HTTP 请求库等） |
| `/api/vision` → 控制端转发逻辑 | 🟡 中 | 视觉数据到控制指令的转换逻辑（业务核心）待实现 |
| 演示视频 | 🟡 中 | `index.html` 中 Demo 视频位置为占位符 |
| 单元测试 | 🟢 低 | 目前无自动化测试 |

---

## 立即可用：Jetson 部署步骤

```bash
# 1. 克隆项目
git clone https://github.com/zsy-smu/v2c-project.git
cd v2c-project

# 2. 一键部署（自动安装 Node.js、配置 systemd）
chmod +x scripts/setup_jetson.sh
./scripts/setup_jetson.sh

# 3. 编辑环境变量（部署完成后）
nano .env

# 4. 验证服务状态
curl http://127.0.0.1:3000/api/health
./scripts/check_service.sh
```

---

## 总结

> **部署基础设施 100% 落地**：文档、脚本、systemd 服务文件、.env 模板均已完整。  
> **最小可运行后端 100% 落地**：`package.json` + `server.js`，`npm start` 可立即运行。  
> **核心业务逻辑待开发**：视觉推理 → 坐标提取 → 控制指令生成链路需要进一步实现。

*报告版本：v1.0 | 最后更新：2026年4月19日*
