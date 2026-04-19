#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
V2C Project — GPIO 按键演示脚本
====================================
功能说明：
  监听树莓派物理按键（默认 GPIO 17 引脚），
  每次按下时向本地 V2C 服务发送一次 HTTP 请求，
  模拟"物理触发 → 服务响应"的交互效果，
  适合展示和演示场景使用。

接线方式（BCM 编号）：
  按键一端 → GPIO 17（物理引脚 11）
  按键另一端 → GND（物理引脚 9）
  （内部上拉电阻已启用，无需额外电阻）

使用方法：
  python3 scripts/gpio_demo.py
  按 Ctrl+C 退出

依赖安装：
  pip3 install RPi.GPIO requests
"""

import time
import sys
import os
import json
from datetime import datetime

# ——————————————————————————————————————————
# 配置区（可根据需要修改）
# ——————————————————————————————————————————

# GPIO 按键引脚编号（BCM 编号，与 .env 中 GPIO_BUTTON_PIN 对应）
try:
    BUTTON_PIN = int(os.environ.get("GPIO_BUTTON_PIN", 17))
except ValueError:
    print("错误：GPIO_BUTTON_PIN 必须为整数，已使用默认值 17")
    BUTTON_PIN = 17

# 防抖延迟（秒），避免一次按键触发多次
try:
    DEBOUNCE_TIME = float(os.environ.get("GPIO_DEBOUNCE_MS", 200)) / 1000
except ValueError:
    print("错误：GPIO_DEBOUNCE_MS 必须为数字，已使用默认值 200ms")
    DEBOUNCE_TIME = 0.2

# 本地服务地址（按下按键后发送请求的目标）
SERVICE_HOST = os.environ.get("HOST", "127.0.0.1")
SERVICE_PORT = os.environ.get("PORT", "3000")
SERVICE_URL = f"http://{SERVICE_HOST}:{SERVICE_PORT}"

# 按下按键时触发的接口路径（根据项目实际 API 修改）
TRIGGER_PATH = "/api/trigger"

# 请求超时时间（秒）
REQUEST_TIMEOUT = 5

# ——————————————————————————————————————————
# 工具函数
# ——————————————————————————————————————————

def log(msg: str, level: str = "信息") -> None:
    """打印带时间戳的日志"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    level_colors = {
        "信息": "\033[1;36m",
        "成功": "\033[1;32m",
        "警告": "\033[1;33m",
        "错误": "\033[1;31m",
    }
    color = level_colors.get(level, "")
    reset = "\033[0m"
    print(f"[{timestamp}] {color}[{level}]{reset} {msg}")


def check_dependencies() -> bool:
    """检查必要依赖是否已安装"""
    missing = []

    try:
        import RPi.GPIO  # noqa: F401
    except ImportError:
        missing.append("RPi.GPIO（安装命令：pip3 install RPi.GPIO）")

    try:
        import requests  # noqa: F401
    except ImportError:
        missing.append("requests（安装命令：pip3 install requests）")

    if missing:
        log("缺少以下依赖，请先安装：", "错误")
        for dep in missing:
            print(f"    → {dep}")
        return False
    return True


def send_trigger_request(press_count: int) -> None:
    """向服务发送按键触发请求"""
    import requests

    payload = {
        "source": "gpio_button",
        "pin": BUTTON_PIN,
        "press_count": press_count,
        "timestamp": datetime.now().isoformat(),
    }

    url = f"{SERVICE_URL}{TRIGGER_PATH}"
    log(f"发送请求 → {url}  载荷：{json.dumps(payload, ensure_ascii=False)}")

    try:
        response = requests.post(url, json=payload, timeout=REQUEST_TIMEOUT)
        if response.status_code < 400:
            log(f"服务响应 {response.status_code}：{response.text[:200]}", "成功")
        else:
            log(f"服务返回错误状态 {response.status_code}：{response.text[:200]}", "警告")
    except requests.exceptions.ConnectionError:
        log(f"无法连接服务（{url}），请确认服务已启动", "错误")
    except requests.exceptions.Timeout:
        log(f"请求超时（{REQUEST_TIMEOUT}s），服务响应过慢", "警告")
    except Exception as e:
        log(f"请求异常：{e}", "错误")


# ——————————————————————————————————————————
# 主程序
# ——————————————————————————————————————————

def main():
    # 检查依赖
    if not check_dependencies():
        sys.exit(1)

    import RPi.GPIO as GPIO

    # 打印启动横幅
    print()
    print("\033[1;36m╔══════════════════════════════════════════════╗\033[0m")
    print("\033[1;36m║     V2C Project — GPIO 按键演示脚本          ║\033[0m")
    print("\033[1;36m╚══════════════════════════════════════════════╝\033[0m")
    print()
    log(f"按键引脚：GPIO {BUTTON_PIN}（BCM 编号）")
    log(f"触发接口：{SERVICE_URL}{TRIGGER_PATH}")
    log(f"防抖延迟：{int(DEBOUNCE_TIME * 1000)}ms")
    log("等待按键… 按 Ctrl+C 退出")
    print()

    # 初始化 GPIO
    GPIO.setmode(GPIO.BCM)
    GPIO.setwarnings(False)
    # 配置引脚为输入，启用内部上拉电阻
    # （按键按下时引脚拉到 GND，读到 LOW；松开时读到 HIGH）
    GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

    press_count = 0
    last_press_time = 0

    try:
        while True:
            # 检测按键按下（低电平）
            if GPIO.input(BUTTON_PIN) == GPIO.LOW:
                current_time = time.time()

                # 防抖处理：距上次触发不足防抖延迟则忽略
                if (current_time - last_press_time) > DEBOUNCE_TIME:
                    last_press_time = current_time
                    press_count += 1

                    log(f"🔘 按键按下！（第 {press_count} 次）", "成功")
                    send_trigger_request(press_count)

                    # 等待按键松开，避免重复触发
                    while GPIO.input(BUTTON_PIN) == GPIO.LOW:
                        time.sleep(0.05)

            time.sleep(0.02)  # 轮询间隔（20ms），降低 CPU 占用

    except KeyboardInterrupt:
        print()
        log("用户中断（Ctrl+C），程序退出", "信息")
        log(f"本次共触发 {press_count} 次", "信息")

    finally:
        # 清理 GPIO 资源
        GPIO.cleanup()
        log("GPIO 资源已释放", "信息")


if __name__ == "__main__":
    main()
