# Raspberry Pi Deployment Guide

Deploy the V2C / NinjiaTag backend on a **Raspberry Pi 4B / 5** running Raspberry Pi OS Lite (64-bit).

---

## 1. Hardware Requirements

| Item | Recommended |
|------|-------------|
| Raspberry Pi | 4B (4 GB+) or Pi 5 |
| MicroSD | 32 GB+ Class 10 / A1 |
| Power supply | Official Pi 27W USB-C (Pi 5) or 15W (Pi 4) |
| Cooling | Heatsink case with fan |
| Network | Ethernet cable (more stable than Wi-Fi for first boot) |

---

## 2. Flash Raspberry Pi OS Lite (64-bit)

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/).
2. Choose **Raspberry Pi OS Lite (64-bit)** (no desktop required).
3. Click the ⚙️ gear icon → enable SSH, set hostname (`v2c-pi`), username, password, and Wi-Fi credentials.
4. Flash to MicroSD and boot the Pi.

---

## 3. First SSH Login

```bash
ssh pi@v2c-pi.local
# or use the IP shown on your router: ssh pi@192.168.x.x
```

Update the system:

```bash
sudo apt update && sudo apt full-upgrade -y
sudo reboot
```

---

## 4. Install Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker
docker --version
```

> **China mirror** (if Docker Hub is unreachable):  
> Edit `/etc/docker/daemon.json`:
> ```json
> {
>   "registry-mirrors": [
>     "https://docker.1ms.run",
>     "https://hub.1panel.dev",
>     "https://docker.itelyou.cf"
>   ]
> }
> ```
> Then `sudo systemctl restart docker`.

---

## 5. Install Node.js (via nvm)

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
source ~/.bashrc
nvm install 22
node -v   # v22.x.x
npm -v    # 10.x.x
```

---

## 6. Install Python Dependencies

```bash
sudo apt install -y python3 python3-pip python3-venv

# System-wide (simpler):
pip3 install aiohttp requests cryptography pycryptodome srp pbkdf2

# Or use a venv (recommended):
python3 -m venv ~/v2c-project/venv
~/v2c-project/venv/bin/pip3 install aiohttp requests cryptography pycryptodome srp pbkdf2
```

---

## 7. Clone the Repository

```bash
git clone https://github.com/zsy-smu/v2c-project.git ~/v2c-project
cd ~/v2c-project
npm install
```

---

## 8. Configure Environment

```bash
cp .env.example .env
nano .env
```

Key variables to set:

| Variable | Example value | Description |
|----------|--------------|-------------|
| `PORT` | `3000` | API server port |
| `DB_PATH` | `./reports.db` | SQLite database path |
| `PYTHON_CMD` | `./venv/bin/python3` | Python executable (venv or `python3`) |
| `ANISETTE_SERVER` | `http://localhost:6969` | Anisette Docker container URL |
| `ENABLE_GPIO` | `false` | Enable physical button trigger |
| `GPIO_BUTTON_PIN` | `18` | BCM pin for button (if ENABLE_GPIO=true) |
| `GPIO_DEBOUNCE_MS` | `300` | Software debounce time in milliseconds |

---

## 9. Start Anisette Docker Container

```bash
docker network create mh-network
docker run -d --restart always --name anisette \
  -p 6969:6969 \
  --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/ \
  --network mh-network \
  dadoum/anisette-v3-server
```

Verify it's running:

```bash
docker ps | grep anisette
curl http://localhost:6969   # Should return a response
```

---

## 10. Place Hardware Keys

Copy your `.key` files into the `keys/` directory:

```bash
# From your laptop:
scp /path/to/your/*.key pi@v2c-pi.local:~/v2c-project/keys/
```

---

## 11. First-Time Apple Authentication

```bash
cd ~/v2c-project
python3 request_reports.py
# Follow the prompts: enter Apple ID, password, and SMS 2FA code
```

This creates a local credential cache so subsequent runs are automatic.

---

## 12. Install systemd Services (auto-start on boot)

```bash
# Install the service units
sudo cp deploy/systemd/v2c-server.service  /etc/systemd/system/
sudo cp deploy/systemd/v2c-report.service  /etc/systemd/system/
sudo cp deploy/systemd/v2c-report.timer    /etc/systemd/system/

# Reload systemd and enable
sudo systemctl daemon-reload
sudo systemctl enable --now v2c-server.service
sudo systemctl enable --now v2c-report.timer

# Check status
sudo systemctl status v2c-server
sudo systemctl status v2c-report.timer
```

---

## 13. Verify Service on LAN

```bash
# From the Pi itself:
curl http://localhost:3000/health

# From another device on the same LAN:
curl http://v2c-pi.local:3000/health
# or
curl http://192.168.x.x:3000/health
```

Expected response:

```json
{
  "status": "ok",
  "db": "connected",
  "port": 3000,
  "uptime": 42.1,
  "timestamp": "2026-04-19T07:00:00.000Z"
}
```

Or use the provided script:

```bash
bash scripts/check_service.sh
```

---

## 14. (Optional) GPIO Button Trigger

Connect a momentary push button between BCM GPIO 18 and GND.

Enable in `.env`:

```
ENABLE_GPIO=true
GPIO_BUTTON_PIN=18
GPIO_TRIGGER_URL=http://localhost:3000/health
```

Install the GPIO Python library:

```bash
pip3 install RPi.GPIO requests
```

Run the GPIO trigger process (or add a dedicated systemd unit):

```bash
python3 scripts/gpio_trigger.py
```

When the button is pressed, `GPIO_TRIGGER_URL` receives a GET request. Customize the endpoint in `.env` to trigger any backend action.

> **Note:** `ENABLE_GPIO=false` (default) means the script exits immediately without touching any GPIO — no impact on normal operation.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `curl /health` returns 503 | Database not initialized; run `python3 request_reports.py` first |
| Port 3000 not reachable from LAN | Check Pi firewall: `sudo ufw allow 3000` |
| Docker pull fails | Configure registry mirrors (see §4) |
| `gsa_authenticate` 503 error | Pi's public IP is banned by Apple — use VPN/different network |
| GPIO button not responding | Check wiring, verify BCM pin number, confirm `ENABLE_GPIO=true` |
