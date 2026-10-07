#!/usr/bin/env bash
set -euo pipefail
#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "        VyperBD Live Monitor Agent"
echo "=============================================="

if [[ $EUID -ne 0 ]]; then
    echo "Please run this installer as root."
    exit 1
fi

echo
read -r -p "Monitor URL (example: https://monitor.vyperbd.cloud): " MONITOR_URL

# Remove trailing slash
MONITOR_URL="${MONITOR_URL%/}"

# Validate URL
if [[ ! "$MONITOR_URL" =~ ^https?://[^/]+$ ]]; then
    echo
    echo "Invalid monitor URL."
    echo "Example:"
    echo "https://monitor.vyperbd.cloud"
    exit 1
fi

HOSTNAME_VALUE="$(hostname)"

echo
read -r -p "Node name [$HOSTNAME_VALUE]: " NODE_NAME
NODE_NAME="${NODE_NAME:-$HOSTNAME_VALUE}"

echo
read -r -p "Location / Network [Auto]: " NETWORK_NAME
NETWORK_NAME="${NETWORK_NAME:-Auto}"

echo
echo "Monitor URL : $MONITOR_URL"
echo "Node Name   : $NODE_NAME"
echo "Network     : $NETWORK_NAME"
echo

echo "Installing VyperBD Monitor Agent..."
echo

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

install -d -m 0755 /opt/vyperbd-monitor
install -d -m 0755 /var/lib/vyperbd-monitor

AGENT_URL="https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/agent/agent.sh"

echo "Downloading agent..."

curl -fL \
    --retry 5 \
    --retry-delay 2 \
    "$AGENT_URL" \
    -o /opt/vyperbd-monitor/agent.sh

chmod 0755 /opt/vyperbd-monitor/agent.sh

cat > /etc/vyperbd-monitor.conf <<EOF
MONITOR_URL="$MONITOR_URL"
NODE_NAME="$NODE_NAME"
NETWORK_NAME="$NETWORK_NAME"
EOF

chmod 0600 /etc/vyperbd-monitor.conf

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

systemctl daemon-reload
systemctl enable vyperbd-monitor-agent
systemctl restart vyperbd-monitor-agent

echo
echo "=============================================="
echo "       Installation Completed"
echo "=============================================="
echo
echo "Monitor URL : $MONITOR_URL"
echo "Node Name   : $NODE_NAME"
echo "Network     : $NETWORK_NAME"
echo
echo "Agent status:"
systemctl --no-pager --full status vyperbd-monitor-agent || true

echo
echo "Live logs:"
echo "journalctl -u vyperbd-monitor-agent -f"
echo
echo "=============================================="
echo "        VyperBD Live Monitor Agent"
echo "=============================================="

if [[ $EUID -ne 0 ]]; then
    echo "Please run as root:"
    echo "curl -fsSL https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/install.sh | sudo bash"
    exit 1
fi

# =========================================================
# CONFIGURATION
# =========================================================

MONITOR_URL="${1:-https://monitor.vyperbd.cloud}"
MONITOR_URL="${MONITOR_URL%/}"

# Validate URL
if [[ ! "$MONITOR_URL" =~ ^https?://[^/]+ ]]; then
    echo "ERROR: Invalid monitor URL: $MONITOR_URL"
    echo
    echo "Example:"
    echo "  https://monitor.vyperbd.cloud"
    exit 1
fi

HOSTNAME_VALUE="$(hostname)"

echo
echo "Monitor URL : $MONITOR_URL"
echo "Hostname    : $HOSTNAME_VALUE"
echo

read -r -p "Node name [$HOSTNAME_VALUE]: " NODE_NAME
NODE_NAME="${NODE_NAME:-$HOSTNAME_VALUE}"

read -r -p "Network/Location [Auto]: " NETWORK_NAME
NETWORK_NAME="${NETWORK_NAME:-Auto}"

echo
echo "Installing VyperBD Monitor Agent..."
echo

# =========================================================
# PACKAGES
# =========================================================

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

echo "Downloading agent..."

curl -fL \
    --retry 5 \
    --retry-delay 2 \
    "$AGENT_URL" \
    -o /opt/vyperbd-monitor/agent.sh

chmod 0755 /opt/vyperbd-monitor/agent.sh

# =========================================================
# CONFIG
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
# ENABLE SERVICE
# =========================================================

systemctl daemon-reload

systemctl enable vyperbd-monitor-agent

systemctl restart vyperbd-monitor-agent

sleep 2

# =========================================================
# STATUS
# =========================================================

echo
echo "=============================================="
echo "       Installation Completed"
echo "=============================================="
echo
echo "Node Name   : $NODE_NAME"
echo "Monitor URL : $MONITOR_URL"
echo "Service     : vyperbd-monitor-agent"
echo
echo "Service status:"
systemctl --no-pager --full status vyperbd-monitor-agent || true
echo
echo "Live logs:"
echo "journalctl -u vyperbd-monitor-agent -f"
echo
echo "=============================================="
