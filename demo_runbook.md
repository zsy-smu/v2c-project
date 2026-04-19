# V2C Project — 演示手册（全流程操作指引）

> 本手册面向现场演示场景，提供从设备上电到演示结束的完整中文操作步骤。
> 适合演示前预演和现场参考使用。

---

## 演示环境一览

| 设备 | 角色 | 说明 |
|------|------|------|
| 树莓派 4B | 后端服务主机 | 运行 V2C 后端，连接局域网 |
| Jetson Orin Nano | 视觉推理端 | 运行 YOLO 目标检测 |
| 笔记本/手机 | 访问终端 | 通过浏览器访问后端接口 |
| 物理按键（可选） | 演示触发器 | GPIO 接钮，按下触发演示流程 |

---

## 演示前准备清单

在演示开始前，请逐项确认：

- [ ] 树莓派电源线已连接，指示灯亮起
- [ ] 树莓派已接入演示场地的局域网（WiFi 或网线）
- [ ] Jetson 设备已开机并连接同一局域网
- [ ] 笔记本/手机与树莓派处于同一局域网
- [ ] 后端服务 `.env` 配置文件已正确填写
- [ ] 物理按键已按说明接线（如使用 GPIO 功能）

---

## 第一阶段：开机上电

### 步骤 1：树莓派上电

1. 连接网线（推荐）或确认 WiFi 已预配置
2. 接入 USB-C 电源，等待约 **30 秒** 系统完全启动
3. 绿色 LED 灯停止频繁闪烁后，系统启动完成

### 步骤 2：确认网络连接

在演示用笔记本上执行：

```bash
# 尝试 ping 树莓派主机名（烧录时设置的主机名）
ping raspberrypi.local

# 或者直接 ping 树莓派固定 IP
ping 192.168.1.200
```

看到 `64 bytes from ...` 输出说明网络已通。

---

## 第二阶段：服务自动启动

树莓派开机后，`v2c-backend` 服务由 **systemd 自动启动**，无需手动操作。

### 验证服务已启动（SSH 登录后执行）

```bash
# SSH 连接树莓派
ssh pi@192.168.1.200

# 查看服务状态
sudo systemctl status v2c-backend

# 期望看到：● v2c-backend.service - V2C Project 后端服务
#              Loaded: loaded (/etc/systemd/system/v2c-backend.service; enabled)
#              Active: active (running) since ...
```

### 或使用一键检查脚本

```bash
# 在树莓派上运行
cd ~/v2c-project
./scripts/check_service.sh
```

---

## 第三阶段：访问服务

### 方式一：浏览器访问

在演示用笔记本或手机浏览器中输入：

```
http://192.168.1.200:3000
```

> 将 `192.168.1.200` 替换为树莓派的实际局域网 IP 地址。

### 方式二：API 接口测试

```bash
# 在笔记本上测试接口连通性（把 IP 替换成实际地址）
curl http://192.168.1.200:3000/api/health

# 期望看到 JSON 响应，例如：{"status":"ok","message":"服务运行正常"}
```

---

## 第四阶段：演示按键触发（GPIO 功能）

> 此阶段需要已按照 `gpio_demo/README.md` 完成接线，并在 `.env` 中设置 `启用GPIO按键=true`。

### 演示效果

**按下物理按键** → GPIO 监听程序检测到信号 → 自动向后端发送 POST 请求 → 后端触发对应业务逻辑

### 步骤说明

1. 确认 `.env` 中 `启用GPIO按键=true`
2. 确认 GPIO 监听程序已运行：

```bash
# 查看 GPIO 监听程序是否在运行
ps aux | grep gpio_button | grep -v grep

# 手动启动（如未运行）
cd ~/v2c-project
python3 gpio_demo/gpio_button.py &
```

3. **按下物理按键**，观察终端输出：

```
2026年04月19日 10:00:00 [INFO] 检测到按键按下（引脚 GPIO 17）
2026年04月19日 10:00:00 [INFO] ✓ 按键触发成功！接口返回状态码：200
```

4. 在后端日志中也能看到请求记录：

```bash
# 查看实时日志
sudo journalctl -u v2c-backend -f
```

---

## 第五阶段：演示结束

```bash
# 如果演示结束需要关闭树莓派（不要直接拔电源！）
sudo shutdown -h now

# 等待绿色 LED 灯熄灭后，再断开电源
```

---

## 常见演示问题处理

### 问题：浏览器无法打开页面

```bash
# 1. 确认在同一局域网
ping 192.168.1.200

# 2. 确认服务正在运行
ssh pi@192.168.1.200 "sudo systemctl status v2c-backend"

# 3. 手动重启服务
ssh pi@192.168.1.200 "sudo systemctl restart v2c-backend"
```

### 问题：服务未启动，需要手动启动

```bash
# SSH 进入树莓派
ssh pi@192.168.1.200

# 手动启动服务
sudo systemctl start v2c-backend

# 等待 3 秒后检查状态
sleep 3 && sudo systemctl status v2c-backend
```

### 问题：忘记树莓派 IP 地址

```bash
# 在同局域网电脑上扫描
nmap -sn 192.168.1.0/24 | grep -B 2 "Raspberry"

# 或者路由器后台查看已连接设备列表
```

### 问题：GPIO 按键无反应

1. 检查接线是否正确（参考 `gpio_demo/README.md`）
2. 确认 `.env` 中 `启用GPIO按键=true`
3. 确认 GPIO 监听程序已运行
4. 查看 GPIO 程序日志输出

---

## 演示话术参考

以下为现场介绍参考文案（可根据实际情况修改）：

> "这个演示展示了 V2C（视觉与控制协同）系统的完整数据流：
> 视觉端的 Jetson 设备实时捕获目标信息，通过局域网传输到运行在树莓派上的后端服务，
> 后端再将处理后的控制指令下发给机器人控制端。
> 整个链路从感知到响应延迟极低，实现了真正的"看到即反应"。
> 现在我来按下这个物理按钮，触发一次完整的演示流程..."

---

*演示手册版本：v1.0 | 最后更新：2026年4月 | 维护者：Zsy @ 上海海事大学*
