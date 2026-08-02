#!/bin/bash
# ============================================================
# Oracle Cloud Free Tier — Relay Server Setup Script
# Run this ONCE on a fresh OCI Always Free VM (Ubuntu/Oracle Linux)
# Usage: ssh into your VM, then:  bash setup_oracle.sh
# ============================================================

set -e

echo "=========================================="
echo "  Territory Break Relay — OCI Setup"
echo "=========================================="

# 1. Install Node.js (LTS) if not already installed
if ! command -v node &> /dev/null; then
    echo "[1/5] Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null || {
        # Fallback for Oracle Linux / RHEL
        curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo -E bash - 2>/dev/null
        sudo yum install -y nodejs 2>/dev/null || sudo dnf install -y nodejs 2>/dev/null
    }
    sudo apt-get install -y nodejs 2>/dev/null || true
else
    echo "[1/5] Node.js already installed: $(node --version)"
fi

# 2. Create app directory
echo "[2/5] Setting up application directory..."
APP_DIR="$HOME/relay-server"
mkdir -p "$APP_DIR"

# Copy files (if running from repo) or create them
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/server.js" ]; then
    cp "$SCRIPT_DIR/server.js" "$APP_DIR/server.js"
    cp "$SCRIPT_DIR/package.json" "$APP_DIR/package.json"
    echo "   Copied server files from repo."
else
    echo "   ERROR: server.js not found. Run this script from the relay_server/ directory."
    exit 1
fi

# 3. Install npm dependencies
echo "[3/5] Installing npm dependencies..."
cd "$APP_DIR"
npm install --production

# 4. Create systemd service (runs on boot, auto-restarts)
echo "[4/5] Creating systemd service..."
sudo tee /etc/systemd/system/relay-server.service > /dev/null <<EOF
[Unit]
Description=Territory Break WebSocket Relay Server
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=$(which node) $APP_DIR/server.js
Restart=always
RestartSec=5
Environment=PORT=9090
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable relay-server
sudo systemctl start relay-server

# 5. Open firewall port 9090
echo "[5/5] Opening firewall port 9090..."
# Ubuntu UFW
if command -v ufw &> /dev/null; then
    sudo ufw allow 9090/tcp 2>/dev/null || true
fi
# Oracle Linux / CentOS firewalld
if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=9090/tcp 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
fi
# iptables fallback
sudo iptables -I INPUT -p tcp --dport 9090 -j ACCEPT 2>/dev/null || true
sudo netfilter-persistent save 2>/dev/null || true

echo ""
echo "=========================================="
echo "  ✅ Relay Server is RUNNING!"
echo "=========================================="
echo ""
echo "  Check status:   sudo systemctl status relay-server"
echo "  View logs:       sudo journalctl -u relay-server -f"
echo "  Restart:         sudo systemctl restart relay-server"
echo ""
echo "  ⚠️  IMPORTANT: You also need to open port 9090 in"
echo "  Oracle Cloud's Security List (see guide below)."
echo ""
echo "  Your relay URL will be:  ws://YOUR_VM_PUBLIC_IP:9090"
echo "  Find your public IP:     curl -s ifconfig.me"
echo ""
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "UNKNOWN")
echo "  Detected public IP: $PUBLIC_IP"
echo "  Relay URL:  ws://$PUBLIC_IP:9090"
echo ""
echo "  Update your Godot project network_manager.gd:"
echo "  const RELAY_URL: String = \"ws://$PUBLIC_IP:9090\""
echo "=========================================="
