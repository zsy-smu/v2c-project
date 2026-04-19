# =============================================================
# V2C Project — GPIO 按键功能说明
# =============================================================
# 此目录包含 Jetson GPIO 物理按键触发后端接口的示例代码。
# 默认为关闭状态，需通过环境变量开启。
#
# 文件说明：
#   gpio_button.py  — GPIO 按键监听主程序
#   README.md       — 本说明文档
#
# 快速开始：
#   1. 按照下方接线图连接物理按键
#   2. 在 .env 文件中设置：启用GPIO按键=true
#   3. 运行：python3 gpio_demo/gpio_button.py
# =============================================================

# V2C GPIO 按键接线说明

## 所需硬件

- Jetson Orin Nano（或其他支持 Jetson.GPIO 的 Jetson 设备）
- 轻触按钮（Tactile Switch）× 1
- 杜邦线（母对母）× 2

## 接线方法

```
Jetson 引脚                  按钮
─────────────────────────────────────
物理引脚 11  (GPIO 17) ──── 按钮引脚 A
物理引脚  6  (GND)    ──── 按钮引脚 B
─────────────────────────────────────
```

内部上拉电阻已在代码中启用，无需外接电阻。

## Jetson 引脚说明

```
请以 Jetson Orin Nano 对应的官方 Pinout 图为准。
建议默认使用 `GPIO按钮引脚=17`，并将另一端接地（GND）。
```

## 环境变量配置

在 `.env` 文件中配置以下变量：

```
启用GPIO按键=true         # 开启 GPIO 功能（默认 false）
GPIO按钮引脚=17           # BCM 引脚编号（默认 17）
GPIO触发接口路径=/api/trigger  # 触发的后端接口路径
服务端口=3000             # 后端服务端口
```

## 运行命令

```bash
# 安装 Jetson GPIO 库（首次部署）
pip3 install Jetson.GPIO

# 直接运行（前台运行，Ctrl+C 停止）
python3 gpio_demo/gpio_button.py

# 后台运行（使用 nohup）
nohup python3 gpio_demo/gpio_button.py &

# 以 systemd 服务运行（推荐，开机自启）
# 参考 deploy/systemd/ 目录创建对应服务文件
```
