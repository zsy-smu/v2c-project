#!/usr/bin/env python3
"""
gpio_trigger.py — Optional GPIO button scaffold for V2C Project physical demo.

How it works:
  - Reads ENABLE_GPIO from environment (or .env file if python-dotenv is available).
  - If ENABLE_GPIO != "true" the script exits immediately — zero impact on normal runs.
  - If enabled, waits for a button press on GPIO_BUTTON_PIN (BCM numbering) and
    fires a GET request to GPIO_TRIGGER_URL.

Usage:
  python3 scripts/gpio_trigger.py

Dependencies (install only when ENABLE_GPIO=true):
  pip3 install RPi.GPIO requests python-dotenv

Wiring:
  Button terminal 1 → BCM GPIO 18 (or value of GPIO_BUTTON_PIN)
  Button terminal 2 → GND (Pin 6 or any GND pin)
  Internal pull-up resistor is enabled by software; no external resistor needed.
"""

import os
import sys
import time

# ── Load .env if python-dotenv is available ───────────────────────────────────
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv not installed; rely on env vars set by shell / systemd

# ── Feature flag — exit early if GPIO is disabled ────────────────────────────
ENABLE_GPIO = os.environ.get("ENABLE_GPIO", "false").strip().lower()
if ENABLE_GPIO != "true":
    print("GPIO trigger disabled (ENABLE_GPIO != true). Exiting.")
    sys.exit(0)

# ── Configuration ─────────────────────────────────────────────────────────────
try:
    BUTTON_PIN = int(os.environ.get("GPIO_BUTTON_PIN", "18"))
except ValueError:
    print("Invalid GPIO_BUTTON_PIN value. Must be an integer BCM pin number.")
    sys.exit(1)

TRIGGER_URL = os.environ.get("GPIO_TRIGGER_URL", "http://localhost:3000/health")
DEBOUNCE_S  = float(os.environ.get("GPIO_DEBOUNCE_MS", "300")) / 1000.0

# ── Import hardware libraries ─────────────────────────────────────────────────
try:
    import RPi.GPIO as GPIO
except ImportError:
    print("RPi.GPIO not installed. Run: pip3 install RPi.GPIO")
    sys.exit(1)

try:
    import requests
except ImportError:
    print("requests not installed. Run: pip3 install requests")
    sys.exit(1)

# ── Setup GPIO ────────────────────────────────────────────────────────────────
GPIO.setmode(GPIO.BCM)
GPIO.setup(BUTTON_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)

print(f"GPIO trigger active on BCM pin {BUTTON_PIN}. Trigger URL: {TRIGGER_URL}")
print("Press the button to fire a request. Ctrl-C to exit.")


def on_button_press(channel):
    """Callback fired on falling edge (button pressed to GND)."""
    time.sleep(DEBOUNCE_S)                    # simple software debounce
    if GPIO.input(channel) == GPIO.LOW:       # still pressed after debounce
        print(f"Button pressed on pin {channel} — firing GET {TRIGGER_URL}")
        try:
            resp = requests.get(TRIGGER_URL, timeout=5)
            print(f"  → HTTP {resp.status_code}: {resp.text[:200]}")
        except requests.RequestException as exc:
            print(f"  → Request failed: {exc}")


GPIO.add_event_detect(
    BUTTON_PIN,
    GPIO.FALLING,
    callback=on_button_press,
    bouncetime=int(DEBOUNCE_S * 1000),
)

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("\nExiting GPIO trigger.")
finally:
    GPIO.cleanup()
