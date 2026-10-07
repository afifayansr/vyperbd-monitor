#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "        VyperBD Live Monitor Agent"
echo "=============================================="

if [[ $EUID -ne 0 ]]; then
  echo "Run as root:"
  echo "  curl -fsSL https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/install.sh | sudo bash"
  exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This installer currently supports Ubuntu/Debian."
  exit 1
fi

read -rp "Monitor URL (example https://monitor.vyperbd.cloud): " MONITOR_URL
MONITOR_URL="${MONITOR_URL%/}"
if [[ -z "$MONITOR_URL" || ! "$MONITOR_URL" =~ ^https?:// ]]; then
  echo "Invalid monitor URL."
  exit 1
fi

read -rp "Node name [$(hostname)]: " NODE_NAME
NODE_NAME="${NODE_NAME:-$(hostname)}"
read -rp "Location/network name (example BDIX, Dhaka) [Auto]: " NETWORK_NAME
NETWORK_NAME="${NETWORK_NAME:-Auto}"

apt-get update -y
apt-get install -y curl openssl iproute2 iputils-ping procps util-linux coreutils ca-certificates

install -d -m 0755 /opt/vyperbd-monitor
curl -fsSL "https://raw.githubusercontent.com/afifayansr/vyperbd-monitor/main/agent/agent.sh" -o /opt/vyperbd-monitor/agent.sh
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
RestartSec=3
User=root
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vyperbd-monitor-agent

echo
echo "Installed successfully."
echo "Node: $NODE_NAME"
echo "Monitor: $MONITOR_URL"
echo
echo "Check:"
echo "  systemctl status vyperbd-monitor-agent"
echo "  journalctl -u vyperbd-monitor-agent -f"
