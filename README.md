# V2C Project

**V2C (Vision-to-Control)** — NinjiaTag FindMy location backend, deployable on any Linux server or Raspberry Pi.

This backend periodically fetches location data from Apple's Find My network and stores it in a local SQLite database. A lightweight Express API lets the [NinjiaTagPage](https://atomgit.com/bd8cca/NinjiaTagPage) frontend query historical tracks, realtime positions, and heatmaps.

---

## Quick Start (local dev)

```bash
# 1. Clone
git clone https://github.com/zsy-smu/v2c-project.git
cd v2c-project

# 2. Copy and fill in environment variables
cp .env.example .env
$EDITOR .env

# 3. Install Node.js dependencies
npm install

# 4. Install Python dependencies
pip3 install aiohttp requests cryptography pycryptodome srp pbkdf2

# 5. Start Anisette server (Docker required)
docker network create mh-network
docker run -d --restart always --name anisette -p 6969:6969 \
  --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/ \
  --network mh-network dadoum/anisette-v3-server

# 6. Place your .key files in the keys/ directory

# 7. Authenticate with Apple (first time only)
python3 request_reports.py

# 8. Start the query server
npm start

# 9. (Optional) Start the report scheduler in another terminal
npm run start:report
```

### Verify the server

```bash
curl http://localhost:3000/health
```

Expected response:

```json
{"status":"ok","db":"connected","port":3000,"uptime":12.3,"timestamp":"..."}
```

---

## Raspberry Pi Deployment

See **[docs/raspberry-pi-deploy.md](docs/raspberry-pi-deploy.md)** for a step-by-step guide including:

- Raspberry Pi OS Lite setup & SSH
- Runtime installation (Node.js, Python, Docker)
- systemd service configuration for auto-start on boot
- LAN healthcheck verification
- Optional GPIO button trigger

---

## Presentation Day Runbook

See **[docs/demo-runbook.md](docs/demo-runbook.md)** for the step-by-step demo checklist.

---

## Project Structure

```
v2c-project/
├── server.mjs              # Express API server (includes /health endpoint)
├── request_reports.mjs     # Node-cron scheduler that calls Python fetcher
├── request_reports.py      # Python: authenticates with Apple & fetches locations
├── pypush_gsa_icloud.py    # Apple GSA/iCloud auth helper
├── package.json
├── .env.example            # Environment variable template
├── keys/                   # Place your .key files here (not committed)
├── docs/
│   ├── raspberry-pi-deploy.md
│   └── demo-runbook.md
├── deploy/
│   └── systemd/            # systemd unit files for Pi auto-start
├── scripts/
│   ├── setup_pi.sh         # One-shot Pi bootstrap script
│   ├── check_service.sh    # Health verification script
│   └── gpio_trigger.py     # Optional GPIO button scaffold
└── index.html              # Project landing page
```

---

## API Endpoints

| Method | Path      | Description                              |
|--------|-----------|------------------------------------------|
| GET    | `/health` | Service healthcheck (status + DB check)  |
| POST   | `/query`  | Query location data (base64 JSON body)   |

---

## License

ISC — see upstream [NinjiaTag-backend](https://github.com/zhzhzhy/NinjiaTag-backend) for full attribution.
