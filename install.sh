#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "        VyperBD Live Monitor Agent"
echo "=============================================="
echo

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Please run this installer as root."
    exit 1
fi

# =========================================================
# MONITOR URL
# =========================================================

if [[ -n "${1:-}" ]]; then
    MONITOR_URL="$1"
else
    if [[ -t 0 ]]; then
        read -r -p "Monitor URL (example: https://monitor.vyperbd.cloud): " MONITOR_URL
    elif [[ -r /dev/tty ]]; then
        read -r -p "Monitor URL (example: https://monitor.vyperbd.cloud): " MONITOR_URL < /dev/tty
    else
        echo "ERROR: Cannot read Monitor URL."
        echo
        echo "Use:"
        echo "curl -fsSL https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/install.sh | sudo bash -s -- https://monitor.vyperbd.cloud"
        exit 1
    fi
fi

MONITOR_URL="${MONITOR_URL%/}"

# =========================================================
# VALIDATE URL
# =========================================================

if [[ ! "$MONITOR_URL" =~ ^https?://[^/]+$ ]]; then
    echo
    echo "Invalid monitor URL."
    echo "Example:"
    echo "https://monitor.vyperbd.cloud"
    exit 1
fi

HOSTNAME_VALUE="$(hostname)"

# =========================================================
# NODE NAME
# =========================================================

if [[ -t 0 ]]; then
    read -r -p "Node name [$HOSTNAME_VALUE]: " NODE_NAME
elif [[ -r /dev/tty ]]; then
    read -r -p "Node name [$HOSTNAME_VALUE]: " NODE_NAME < /dev/tty
else
    NODE_NAME="$HOSTNAME_VALUE"
fi

NODE_NAME="${NODE_NAME:-$HOSTNAME_VALUE}"

# =========================================================
# LOCATION / NETWORK
# =========================================================

if [[ -t 0 ]]; then
    read -r -p "Location / Network [Auto]: " NETWORK_NAME
elif [[ -r /dev/tty ]]; then
    read -r -p "Location / Network [Auto]: " NETWORK_NAME < /dev/tty
else
    NETWORK_NAME="Auto"
fi

NETWORK_NAME="${NETWORK_NAME:-Auto}"

echo
echo "=============================================="
echo "Monitor URL : $MONITOR_URL"
echo "Node Name   : $NODE_NAME"
echo "Network     : $NETWORK_NAME"
echo "=============================================="
echo

# =========================================================
# INSTALL PACKAGES
# =========================================================

echo "Installing dependencies..."

export DEBIAN_FRONTEND=noninteractive

apt-get update -y

apt-get install -y \
    curl \
    openssl \
    iproute2 \
    iputils-ping \
    procps \
    util-linux \
    coreutils \
    ca-certificates

# =========================================================
# DIRECTORIES
# =========================================================

install -d -m 0755 /opt/vyperbd-monitor
install -d -m 0755 /var/lib/vyperbd-monitor

# =========================================================
# DOWNLOAD AGENT
# =========================================================

AGENT_URL="https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/agent/agent.sh"

echo "Downloading monitoring agent..."

curl -fL \
    --retry 5 \
    --retry-delay 2 \
    "$AGENT_URL" \
    -o /opt/vyperbd-monitor/agent.sh

chmod 0755 /opt/vyperbd-monitor/agent.sh

# =========================================================
# CONFIGURATION
# =========================================================

cat > /etc/vyperbd-monitor.conf <<EOF
MONITOR_URL="$MONITOR_URL"
NODE_NAME="$NODE_NAME"
NETWORK_NAME="$NETWORK_NAME"
EOF

chmod 0600 /etc/vyperbd-monitor.conf

# =========================================================
# SYSTEMD SERVICE
# =========================================================

cat > /etc/systemd/system/vyperbd-monitor-agent.service <<'EOF'
[Unit]
Description=VyperBD Live Monitor Agent
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

[Install]
WantedBy=multi-user.target
EOF

# =========================================================
# START
# =========================================================

systemctl daemon-reload

systemctl enable vyperbd-monitor-agent

systemctl restart vyperbd-monitor-agent

sleep 2

# =========================================================
# RESULT
# =========================================================

echo
echo "=============================================="
echo "       Installation Completed"
echo "=============================================="
echo
echo "Monitor URL : $MONITOR_URL"
echo "Node Name   : $NODE_NAME"
echo "Network     : $NETWORK_NAME"
echo
echo "Agent service:"
systemctl --no-pager --full status vyperbd-monitor-agent || true
echo
echo "Live logs:"
echo "journalctl -u vyperbd-monitor-agent -f"
echo
echo "=============================================="
