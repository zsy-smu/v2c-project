# =============================================================
# V2C Project — GPIO 按键功能说明
# =============================================================
# 此目录包含物理按键触发后端接口的示例代码。
# 支持树莓派（RPi.GPIO）和 Jetson 系列（Jetson.GPIO），自动探测。
# 默认为关闭状态，需通过环境变量开启。
#
# 文件说明：
#   gpio_button.py  — GPIO 按键监听主程序
#   README.md       — 本说明文档
#
# 快速开始：
#   1. 按照下方接线图连接物理按键
#   2. 在 .env 文件中设置：GPIO_ENABLE=true
#   3. 运行：python3 gpio_demo/gpio_button.py
# =============================================================

# V2C GPIO 按键接线说明

## 所需硬件

- 树莓派（任意型号，带 GPIO 接口）或 Jetson 系列开发板
- 轻触按钮（Tactile Switch）× 1
- 杜邦线（母对母）× 2

## 接线方法

```
开发板引脚                  按钮
─────────────────────────────────────
物理引脚 11  (GPIO 17) ──── 按钮引脚 A
物理引脚  6  (GND)    ──── 按钮引脚 B
─────────────────────────────────────
```

内部上拉电阻已在代码中启用，无需外接电阻。

## 引脚图（部分，BCM 编号）

```
       3.3V [1]  [2] 5V
  GPIO 2   [3]  [4] 5V
  GPIO 3   [5]  [6] GND  ← 接按钮另一端
  GPIO 4   [7]  [8] GPIO 14
       GND [9] [10] GPIO 15
  GPIO 17 [11] [12] GPIO 18  ← 接按钮一端（默认引脚）
```

> 树莓派与 Jetson Orin Nano 的 40 针 GPIO 布局相同，接线方式一致。

## GPIO 库安装

| 设备 | GPIO 库 | 安装命令 |
|------|---------|---------|
| 树莓派 | RPi.GPIO | `sudo apt install python3-rpi.gpio` |
| Jetson | Jetson.GPIO | `sudo pip3 install Jetson.GPIO` |

脚本会自动探测已安装的库（先尝试 RPi.GPIO，再尝试 Jetson.GPIO），**无需修改代码**。

## 环境变量配置

在 `.env` 文件中配置以下变量（key 均为标准 ASCII，兼容 systemd）：

```
GPIO_ENABLE=true           # 开启 GPIO 功能（默认 false）
GPIO_BUTTON_PIN=17         # BCM 引脚编号（默认 17）
GPIO_TRIGGER_PATH=/api/trigger  # 触发的后端接口路径
PORT=3000                  # 后端服务端口
```

## 运行命令

```bash
# 直接运行（前台运行，Ctrl+C 停止）
python3 gpio_demo/gpio_button.py

# 后台运行（使用 nohup）
nohup python3 gpio_demo/gpio_button.py &

# 以 systemd 服务运行（推荐，开机自启）
# 参考 deploy/systemd/ 目录创建对应服务文件
```

## Jetson 额外配置（首次使用）

Jetson 上使用 GPIO 需要将用户加入 gpio 用户组：

```bash
sudo groupadd -f -r gpio
sudo usermod -a -G gpio nvidia
# 重新登录后生效
```
