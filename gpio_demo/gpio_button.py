#!/usr/bin/env python3
# =============================================================
# V2C Project — GPIO 物理按键触发后端接口示例
# 文件：gpio_demo/gpio_button.py
# 功能：监听物理按键，按下时向后端服务发送 HTTP 请求
# 默认状态：关闭（需通过环境变量 启用GPIO按键=true 开启）
#
# 支持设备：
#   - 树莓派（使用 RPi.GPIO 库）
#   - NVIDIA Jetson Orin Nano / Nano / Xavier 等（使用 Jetson.GPIO 库）
#   脚本会自动检测当前设备并选择正确的库，无需手动修改代码
#
# 硬件接线说明：
#   - 轻触按钮一端 → GPIO 17 引脚（物理引脚 11）
#   - 轻触按钮另一端 → GND（物理引脚 6，或任意 GND 引脚）
#   - 内部上拉电阻已启用，无需额外连接 3.3V
#
# 引脚对照（BCM 编号，树莓派与 Jetson 40 针接口相同）：
#   物理引脚 1  = 3.3V 电源
#   物理引脚 6  = GND 接地
#   物理引脚 11 = GPIO 17（本脚本默认按钮引脚）
#   物理引脚 13 = GPIO 27（可选备用引脚）
#
# 使用方法（树莓派）：
#   sudo apt install -y python3-rpi.gpio
#   export 启用GPIO按键=true
#   python3 gpio_demo/gpio_button.py
#
# 使用方法（Jetson Orin Nano / JetPack 6.1）：
#   sudo pip3 install Jetson.GPIO
#   sudo usermod -aG gpio $USER   # 重新登录 SSH 使权限生效
#   export 启用GPIO按键=true
#   python3 gpio_demo/gpio_button.py
# =============================================================

import os
import sys
import time
import logging

# 配置日志格式（中文时间前缀 + 日志级别 + 消息）
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y年%m月%d日 %H:%M:%S"
)
日志 = logging.getLogger("GPIO按键监听")

# -------------------------------------------------------
# 从环境变量读取配置（默认值见下方注释）
# -------------------------------------------------------

# 是否启用 GPIO 按键功能（环境变量：启用GPIO按键，默认：false）
GPIO功能已启用 = os.environ.get("启用GPIO按键", "false").lower() == "true"

# GPIO 按钮连接的引脚编号，使用 BCM 编号（环境变量：GPIO按钮引脚，默认：17）
GPIO按钮引脚 = int(os.environ.get("GPIO按钮引脚", "17"))

# 触发时调用的后端接口地址（环境变量：GPIO触发接口路径，默认：/api/trigger）
触发接口路径 = os.environ.get("GPIO触发接口路径", "/api/trigger")

# 后端服务端口（环境变量：服务端口，默认：3000）
后端端口 = int(os.environ.get("服务端口", "3000"))

# 完整的触发接口 URL
触发接口地址 = f"http://127.0.0.1:{后端端口}{触发接口路径}"

# 按键防抖动时间（单位：秒，避免一次按键触发多次）
防抖延迟 = 0.3


def 检查GPIO功能是否开启():
    """检查环境变量，未开启时打印说明并退出"""
    if not GPIO功能已启用:
        日志.warning("GPIO 按键功能未启用")
        日志.warning("如需开启，请设置环境变量：export 启用GPIO按键=true")
        日志.warning("或在 .env 文件中将「启用GPIO按键」改为 true")
        日志.info("程序退出（功能默认关闭，安全退出，无任何影响）")
        sys.exit(0)


def 导入GPIO库():
    """
    自动检测当前设备类型，优先尝试 Jetson.GPIO（Jetson 设备），
    fallback 到 RPi.GPIO（树莓派）。两个库的 API 接口完全兼容。
    """
    # 优先尝试 Jetson.GPIO（NVIDIA Jetson 系列设备）
    try:
        import Jetson.GPIO as GPIO
        日志.info("检测到 Jetson 设备，使用 Jetson.GPIO 库")
        return GPIO
    except (ImportError, RuntimeError):
        pass

    # Fallback：尝试 RPi.GPIO（树莓派）
    try:
        import RPi.GPIO as GPIO
        日志.info("检测到树莓派设备，使用 RPi.GPIO 库")
        return GPIO
    except ImportError:
        日志.error("无法导入 GPIO 库（Jetson.GPIO 和 RPi.GPIO 均不可用）")
        日志.error("Jetson 设备请安装：sudo pip3 install Jetson.GPIO")
        日志.error("树莓派请安装：sudo apt install python3-rpi.gpio")
        sys.exit(1)
    except RuntimeError as 错误:
        日志.error(f"GPIO 初始化失败：{错误}")
        日志.error("请确认以 root 或 sudo 运行，或将当前用户加入 gpio 用户组")
        日志.error("Jetson：sudo usermod -aG gpio $USER  （重新登录 SSH 后生效）")
        sys.exit(1)


def 发送触发请求():
    """
    按键按下时，向后端服务发送 HTTP POST 请求。
    成功和失败均有中文日志输出。
    """
    try:
        import urllib.request
        import json

        # 构造请求数据（可按实际接口要求修改）
        请求数据 = json.dumps({
            "来源": "GPIO物理按键",
            "触发时间": time.strftime("%Y-%m-%d %H:%M:%S"),
            "引脚编号": GPIO按钮引脚
        }).encode("utf-8")

        # 发送 POST 请求，超时 5 秒
        请求对象 = urllib.request.Request(
            触发接口地址,
            data=请求数据,
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(请求对象, timeout=5) as 响应:
            状态码 = 响应.getcode()
            日志.info(f"✓ 按键触发成功！接口返回状态码：{状态码}")

    except Exception as 错误:
        日志.warning(f"✗ 按键触发失败：{错误}")
        日志.warning(f"  目标接口：{触发接口地址}")
        日志.warning("  请确认后端服务已启动，或检查接口路径配置")


def 按键回调函数(引脚编号):
    """
    GPIO 中断回调函数，当按键引脚电平变化时触发。
    参数：引脚编号 — 触发事件的 GPIO 引脚号
    """
    日志.info(f"检测到按键按下（引脚 GPIO {引脚编号}）")
    发送触发请求()


def 初始化GPIO(GPIO):
    """
    配置 GPIO 引脚模式和中断监听。
    使用 BCM 引脚编号方式（芯片编号，非物理位置编号）。
    """
    # 设置引脚编号使用 BCM 方式（推荐，与引脚丝印上的 GPIO 号一致）
    GPIO.setmode(GPIO.BCM)

    # 配置按钮引脚为输入模式，并启用内部上拉电阻
    # 上拉电阻：默认高电平（3.3V），按键按下后接地变低电平
    GPIO.setup(GPIO按钮引脚, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    # 注册下降沿中断（高→低，即按键按下时触发）
    # bouncetime：防抖时间（毫秒），避免抖动导致多次触发
    GPIO.add_event_detect(
        GPIO按钮引脚,
        GPIO.FALLING,                         # 下降沿（按下触发）
        callback=按键回调函数,                 # 触发时执行的函数
        bouncetime=int(防抖延迟 * 1000)       # 防抖时间（毫秒）
    )

    日志.info(f"GPIO 初始化完成，监听引脚：GPIO {GPIO按钮引脚}（物理引脚 11）")
    日志.info("按下物理按键以触发后端接口...")


def 主循环(GPIO):
    """
    主循环：保持程序运行，等待按键中断。
    Ctrl+C 时优雅退出并清理 GPIO 资源。
    """
    try:
        日志.info("GPIO 按键监听服务已启动，按 Ctrl+C 停止")
        日志.info(f"触发目标：{触发接口地址}")

        # 无限循环等待按键事件（中断由后台线程处理）
        while True:
            time.sleep(1)

    except KeyboardInterrupt:
        日志.info("收到停止信号（Ctrl+C），正在退出...")

    finally:
        # 清理 GPIO 资源，避免引脚状态残留影响下次使用
        GPIO.cleanup()
        日志.info("GPIO 资源已释放，程序正常退出")


def main():
    """程序入口，按顺序执行各初始化步骤"""
    日志.info("V2C Project — GPIO 按键监听服务启动")

    # 第一步：检查功能开关
    检查GPIO功能是否开启()

    # 第二步：导入 GPIO 库
    GPIO = 导入GPIO库()

    # 第三步：初始化 GPIO 引脚
    初始化GPIO(GPIO)

    # 第四步：进入主循环，等待按键
    主循环(GPIO)


if __name__ == "__main__":
    main()
