#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# VyperBD Live Monitor - Linux Agent Installer
# Repository:
# https://github.com/afifayansr/vyperbd-monitor
# =========================================================

clear

echo "=============================================="
echo "        VyperBD Live Monitor Agent"
echo "=============================================="
echo

# =========================================================
# ROOT CHECK
# =========================================================

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: This installer must be run as root."
    echo
    echo "Run:"
    echo "curl -fsSL https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/install.sh | sudo bash"
    exit 1
fi

# =========================================================
# MONITOR URL
# =========================================================

if [[ -n "${1:-}" ]]; then

    MONITOR_URL="$1"

else

    if [[ -r /dev/tty ]]; then

        printf "Monitor URL (example: https://monitor.vyperbd.cloud): "
        read -r MONITOR_URL < /dev/tty

    else

        echo "ERROR: Cannot access terminal input."
        echo
        echo "Use:"
        echo
        echo "curl -fsSL https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/install.sh | sudo bash -s -- https://monitor.vyperbd.cloud"
        exit 1

    fi

fi

# Remove trailing slash
MONITOR_URL="${MONITOR_URL%/}"

# =========================================================
# URL VALIDATION
# =========================================================

if [[ ! "$MONITOR_URL" =~ ^https?://[^/]+$ ]]; then

    echo
    echo "Invalid monitor URL."
    echo
    echo "Example:"
    echo "https://monitor.vyperbd.cloud"
    echo

    exit 1

fi

# =========================================================
# HOSTNAME
# =========================================================

HOSTNAME_VALUE="$(hostname)"

echo
printf "Node name [%s]: " "$HOSTNAME_VALUE"
read -r NODE_NAME < /dev/tty

NODE_NAME="${NODE_NAME:-$HOSTNAME_VALUE}"

# =========================================================
# NETWORK / LOCATION
# =========================================================

echo
printf "Location / Network [Auto]: "
read -r NETWORK_NAME < /dev/tty

NETWORK_NAME="${NETWORK_NAME:-Auto}"

# =========================================================
# SHOW CONFIGURATION
# =========================================================

echo
echo "=============================================="
echo "Installation Configuration"
echo "=============================================="
echo
echo "Monitor URL : $MONITOR_URL"
echo "Node Name   : $NODE_NAME"
echo "Network     : $NETWORK_NAME"
echo
echo "=============================================="
echo

# =========================================================
# INSTALL DEPENDENCIES
# =========================================================

echo "[1/7] Installing dependencies..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

apt-get install -y \
    curl \
    openssl \
    ca-certificates \
    iproute2 \
    iputils-ping \
    procps \
    util-linux \
    coreutils \
    gawk \
    sed \
    grep

echo "Dependencies installed."

# =========================================================
# CREATE DIRECTORIES
# =========================================================

echo
echo "[2/7] Creating directories..."

install -d -m 0755 /opt/vyperbd-monitor
install -d -m 0755 /var/lib/vyperbd-monitor

# =========================================================
# DOWNLOAD AGENT
# =========================================================

echo
echo "[3/7] Downloading monitoring agent..."

AGENT_URL="https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/agent/agent.sh"

curl \
    --fail \
    --location \
    --silent \
    --show-error \
    --retry 5 \
    --retry-delay 2 \
    "$AGENT_URL" \
    -o /opt/vyperbd-monitor/agent.sh

chmod 0755 /opt/vyperbd-monitor/agent.sh

echo "Agent downloaded."

# =========================================================
# GENERATE NODE ID
# =========================================================

echo
echo "[4/7] Generating node identity..."

UUID_FILE="/var/lib/vyperbd-monitor/node_uuid"
TOKEN_FILE="/var/lib/vyperbd-monitor/node_token"

if [[ ! -f "$UUID_FILE" ]]; then

    if [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid > "$UUID_FILE"
    else
        uuidgen > "$UUID_FILE"
    fi

fi

if [[ ! -f "$TOKEN_FILE" ]]; then

    umask 077
    openssl rand -hex 32 > "$TOKEN_FILE"

fi

chmod 0600 "$UUID_FILE"
chmod 0600 "$TOKEN_FILE"

NODE_UUID="$(cat "$UUID_FILE")"

echo "Node ID: $NODE_UUID"

# =========================================================
# CREATE CONFIG
# =========================================================

echo
echo "[5/7] Creating agent configuration..."

cat > /etc/vyperbd-monitor.conf <<EOF
MONITOR_URL="$MONITOR_URL"
NODE_NAME="$NODE_NAME"
NETWORK_NAME="$NETWORK_NAME"
EOF

chmod 0600 /etc/vyperbd-monitor.conf

echo "Configuration saved."

# =========================================================
# CREATE SYSTEMD SERVICE
# =========================================================

echo
echo "[6/7] Creating systemd service..."

cat > /etc/systemd/system/vyperbd-monitor-agent.service <<'EOF'
[Unit]
Description=VyperBD Live Monitor Agent
Documentation=https://github.com/afifayansr/vyperbd-monitor
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

ExecStart=/opt/vyperbd-monitor/agent.sh

Restart=always
RestartSec=5

User=root

NoNewPrivileges=true
PrivateTmp=true

# Give the agent enough time to start after boot
TimeoutStartSec=30
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

# =========================================================
# ENABLE SERVICE
# =========================================================

echo
echo "[7/7] Starting monitoring agent..."

systemctl daemon-reload

systemctl enable vyperbd-monitor-agent

systemctl restart vyperbd-monitor-agent

sleep 3

# =========================================================
# FINAL STATUS
# =========================================================

echo
echo "=============================================="
echo "      VYPERBD MONITOR INSTALLED"
echo "=============================================="
echo
echo "Monitor URL : $MONITOR_URL"
echo "Node Name   : $NODE_NAME"
echo "Network     : $NETWORK_NAME"
echo "Node ID     : $NODE_UUID"
echo
echo "Service:"
echo "  vyperbd-monitor-agent"
echo
echo "Status:"
echo

systemctl --no-pager --full status vyperbd-monitor-agent || true

echo
echo "=============================================="
echo "Useful commands"
echo "=============================================="
echo
echo "Check status:"
echo "systemctl status vyperbd-monitor-agent"
echo
echo "Live logs:"
echo "journalctl -u vyperbd-monitor-agent -f"
echo
echo "Restart:"
echo "systemctl restart vyperbd-monitor-agent"
echo
echo "Stop:"
echo "systemctl stop vyperbd-monitor-agent"
echo
echo "=============================================="
echo "Made by Afifayan | afifayan.fun"
echo "=============================================="
