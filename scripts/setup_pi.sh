#!/usr/bin/env bash
# setup_pi.sh — One-shot Raspberry Pi bootstrap for V2C Project
# Usage: bash scripts/setup_pi.sh
# Run as the 'pi' user (not root). Uses sudo internally where needed.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NODE_VERSION="22"

log()  { echo -e "\033[1;32m[setup]\033[0m $*"; }
warn() { echo -e "\033[1;33m[warn]\033[0m  $*"; }
die()  { echo -e "\033[1;31m[error]\033[0m $*" >&2; exit 1; }

# ── 1. System update ──────────────────────────────────────────────────────────
log "Updating system packages..."
sudo apt-get update -qq
sudo apt-get upgrade -y -qq

# ── 2. Install system dependencies ───────────────────────────────────────────
log "Installing system dependencies..."
sudo apt-get install -y -qq \
    git curl wget ca-certificates \
    python3 python3-pip python3-venv \
    sqlite3

# ── 3. Docker ─────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    log "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    warn "You may need to run 'newgrp docker' or log out/in for Docker group to take effect."
else
    log "Docker already installed: $(docker --version)"
fi

# ── 4. Node.js via nvm ───────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
if [ ! -d "$NVM_DIR" ]; then
    log "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
fi
# shellcheck source=/dev/null
source "$NVM_DIR/nvm.sh"
log "Installing Node.js ${NODE_VERSION}..."
nvm install "$NODE_VERSION"
nvm use "$NODE_VERSION"
nvm alias default "$NODE_VERSION"

# ── 5. Python venv + dependencies ────────────────────────────────────────────
log "Setting up Python venv..."
python3 -m venv "$PROJECT_DIR/venv"
"$PROJECT_DIR/venv/bin/pip3" install --upgrade pip -q
"$PROJECT_DIR/venv/bin/pip3" install -q \
    aiohttp requests cryptography pycryptodome srp pbkdf2

# ── 6. Node.js dependencies ──────────────────────────────────────────────────
log "Installing Node.js dependencies..."
cd "$PROJECT_DIR"
npm install --silent

# ── 7. Environment file ──────────────────────────────────────────────────────
if [ ! -f "$PROJECT_DIR/.env" ]; then
    log "Creating .env from .env.example..."
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    # Default to venv python
    sed -i "s|^PYTHON_CMD=.*|PYTHON_CMD=$PROJECT_DIR/venv/bin/python3|" "$PROJECT_DIR/.env"
    warn "Edit $PROJECT_DIR/.env to set your Apple ID credentials and other settings."
else
    log ".env already exists, skipping."
fi

# ── 8. Keys directory ────────────────────────────────────────────────────────
mkdir -p "$PROJECT_DIR/keys"
log "Place your .key files in: $PROJECT_DIR/keys/"

# ── 9. Anisette Docker container ─────────────────────────────────────────────
log "Starting Anisette server..."
docker network create mh-network 2>/dev/null || true
if ! docker ps -a --format '{{.Names}}' | grep -q '^anisette$'; then
    docker run -d --restart always --name anisette \
        -p 6969:6969 \
        --volume anisette-v3_data:/home/Alcoholic/.config/anisette-v3/ \
        --network mh-network \
        dadoum/anisette-v3-server
    log "Anisette container started."
else
    docker start anisette 2>/dev/null || true
    log "Anisette container already exists, ensured it's running."
fi

# ── 10. Determine Node binary path ───────────────────────────────────────────
NODE_BIN_PATH="$(nvm which "$NODE_VERSION")"
NODE_BIN_DIR="$(dirname "$NODE_BIN_PATH")"

# ── 11. systemd services ─────────────────────────────────────────────────────
log "Installing systemd service units..."

PI_USER="$USER"
ESCAPED_PROJECT_DIR="${PROJECT_DIR//\//\\/}"
ESCAPED_NODE_DIR="${NODE_BIN_DIR//\//\\/}"

for UNIT in v2c-server.service v2c-report.service v2c-report.timer; do
    SRC="$PROJECT_DIR/deploy/systemd/$UNIT"
    DST="/etc/systemd/system/$UNIT"
    # Substitute paths
    sed \
        -e "s|/home/pi/v2c-project|$PROJECT_DIR|g" \
        -e "s|User=pi|User=$PI_USER|g" \
        -e "s|/home/pi/.nvm/versions/node/v22/bin|$NODE_BIN_DIR|g" \
        "$SRC" | sudo tee "$DST" > /dev/null
    log "  Installed $UNIT -> $DST"
done

sudo systemctl daemon-reload
sudo systemctl enable --now v2c-server.service
sudo systemctl enable --now v2c-report.timer

# ── 12. GPIO library (optional) ──────────────────────────────────────────────
if grep -q "ENABLE_GPIO=true" "$PROJECT_DIR/.env" 2>/dev/null; then
    log "ENABLE_GPIO=true detected — installing RPi.GPIO..."
    "$PROJECT_DIR/venv/bin/pip3" install -q RPi.GPIO
fi

# ── Done ──────────────────────────────────────────────────────────────────────
log ""
log "✅  Setup complete!"
log ""
log "Next steps:"
log "  1. Copy .key files to $PROJECT_DIR/keys/"
log "  2. Run: cd $PROJECT_DIR && python3 request_reports.py   (Apple auth)"
log "  3. Check health: curl http://localhost:3000/health"
log "  4. See full guide: $PROJECT_DIR/docs/raspberry-pi-deploy.md"
