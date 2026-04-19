# Presentation Day Demo Runbook

> **Audience:** V2C Project physical demo — NinjiaTag backend on Raspberry Pi  
> **Estimated time to ready:** ~3 minutes from power-on

---

## Pre-Demo Checklist (day before)

- [ ] Pi is flashed, SSH accessible, all services installed
- [ ] `v2c-server.service` and `v2c-report.timer` are enabled
- [ ] At least one `.key` file is present in `~/v2c-project/keys/`
- [ ] Apple auth has been completed (`request_reports.py` ran successfully at least once)
- [ ] Database has location data (`ls -lh ~/v2c-project/reports.db`)
- [ ] Physical button wired to GPIO 18 (if using GPIO demo)
- [ ] Frontend URL noted: `https://bd8cca.atomgit.net/NinjiaTagPage/`
- [ ] Pi's LAN IP noted (e.g., `192.168.1.42`) or hostname `v2c-pi.local`

---

## On Demo Day

### Step 1 — Power On

Connect Pi to power. Wait ~30 seconds for boot.

```
🟢 Power LED solid
🟢 Activity LED stops flashing (boot complete)
```

### Step 2 — Confirm Service is Up

From any device on the same LAN:

```bash
curl http://v2c-pi.local:3000/health
```

Or run the check script from a laptop connected via SSH:

```bash
ssh pi@v2c-pi.local "bash ~/v2c-project/scripts/check_service.sh"
```

Expected output:

```
✅ v2c-server is running
✅ /health returned: ok  (uptime: 42s)
✅ DB connected
```

### Step 3 — Open Frontend

Open a browser and navigate to:

```
https://bd8cca.atomgit.net/NinjiaTagPage/
```

Set the **Server URL** to:

```
http://192.168.x.x:3000/query
```

*(replace with your Pi's actual IP; use HTTP not HTTPS for local LAN)*

### Step 4 — Import Keys and Query Data

1. Click **物品管理 (Item Management)** → **解析 JSON 密钥文件**
2. Import your `.json` key file
3. Click **数据选择 (Data Selection)** → choose item and time range → **查询**
4. Switch between **轨迹点 / 热图 / 最新位置** views

### Step 5 — GPIO Demo (if enabled)

Press the physical button on the Pi.  
A GET request fires to `GPIO_TRIGGER_URL` — observe the terminal output or add a custom action in `scripts/gpio_trigger.py`.

```bash
# Watch live on the Pi:
ssh pi@v2c-pi.local "journalctl -u v2c-server -f"
```

---

## Quick Status Commands (SSH on Pi)

```bash
# Service status
sudo systemctl status v2c-server
sudo systemctl status v2c-report.timer

# Live logs
journalctl -u v2c-server -f
journalctl -u v2c-report -f

# Check DB size
ls -lh ~/v2c-project/reports.db

# Restart if needed
sudo systemctl restart v2c-server
```

---

## Emergency Recovery

| Problem | Command |
|---------|---------|
| Service not started | `sudo systemctl start v2c-server` |
| Port blocked | `sudo ufw allow 3000` |
| DB empty | `python3 ~/v2c-project/request_reports.py` |
| Docker anisette down | `docker start anisette` |

---

## Architecture Summary (for audience)

```
[NinjiaTag BLE Beacon]
        │  (Bluetooth, Apple Find My network)
        ▼
[Apple Find My Network]
        │  (HTTPS, every 5 min via cron)
        ▼
[Raspberry Pi 4B]
  ├── Anisette Server (Docker :6969)
  ├── request_reports.py  → reports.db (SQLite)
  └── server.mjs          → :3000/query
        │
        ▼  (LAN HTTP)
[Browser / Laptop]
  └── NinjiaTagPage (Vue3 + Mapbox-GL)
```
