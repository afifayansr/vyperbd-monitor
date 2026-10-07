#!/usr/bin/env bash
set -u

CONFIG="/etc/vyperbd-monitor.conf"
SERVICE="/etc/systemd/system/vyperbd-monitor-agent.service"

if [[ ! -f "$CONFIG" ]]; then
  echo "Missing $CONFIG"
  exit 1
fi
source "$CONFIG"

mkdir -p /var/lib/vyperbd-monitor
UUID_FILE="/var/lib/vyperbd-monitor/node_uuid"
TOKEN_FILE="/var/lib/vyperbd-monitor/node_token"

[[ -f "$UUID_FILE" ]] || cat /proc/sys/kernel/random/uuid > "$UUID_FILE"
[[ -f "$TOKEN_FILE" ]] || (umask 077; openssl rand -hex 32 > "$TOKEN_FILE")
NODE_UUID="$(cat "$UUID_FILE")"
NODE_TOKEN="$(cat "$TOKEN_FILE")"

get_cpu_usage() {
  read -r _ u n s i w q sq st _ < /proc/stat
  total1=$((u+n+s+i+w+q+sq+st)); idle1=$((i+w))
  sleep 0.25
  read -r _ u n s i w q sq st _ < /proc/stat
  total2=$((u+n+s+i+w+q+sq+st)); idle2=$((i+w))
  dt=$((total2-total1)); di=$((idle2-idle1))
  awk -v dt="$dt" -v di="$di" 'BEGIN{if(dt<=0) print 0; else printf "%.2f", (dt-di)*100/dt}'
}
get_cpu_model(){ lscpu 2>/dev/null | awk -F: '/Model name/{sub(/^[ \t]+/,"",$2);print $2;exit}'; }
get_cpu_vendor(){ lscpu 2>/dev/null | awk -F: '/Vendor ID/{sub(/^[ \t]+/,"",$2);print $2;exit}'; }
get_cores(){ nproc 2>/dev/null || echo 0; }
get_threads(){ lscpu 2>/dev/null | awk -F: '/CPU\(s\):/{sub(/^[ \t]+/,"",$2);print $2;exit}'; }
get_mhz(){ lscpu 2>/dev/null | awk -F: '/CPU max MHz/{sub(/^[ \t]+/,"",$2);print $2;exit}'; }

mem_total(){ awk '/MemTotal:/{print $2*1024}' /proc/meminfo; }
mem_available(){ awk '/MemAvailable:/{print $2*1024}' /proc/meminfo; }

disk_total(){ df -B1 --output=size / 2>/dev/null | tail -1 | tr -d ' '; }
disk_used(){ df -B1 --output=used / 2>/dev/null | tail -1 | tr -d ' '; }

default_iface(){
  ip route 2>/dev/null | awk '/default/{print $5;exit}'
}
iface_speed(){
  local i="$1"
  if [[ -r "/sys/class/net/$i/speed" ]]; then
    s=$(cat "/sys/class/net/$i/speed" 2>/dev/null || echo 0)
    [[ "$s" =~ ^[0-9]+$ ]] && [[ "$s" -gt 0 ]] && echo "${s} Mbps" && return
  fi
  command -v ethtool >/dev/null 2>&1 && ethtool "$i" 2>/dev/null | awk -F': ' '/Speed:/{print $2;exit}'
}
net_bytes(){
  local i="$1"
  awk -v dev="$i" '$1 ~ dev":" {print $2,$10}' /proc/net/dev | head -1
}
public_ip(){ curl -4fsS --max-time 3 https://api.ipify.org 2>/dev/null || echo ""; }

location_json(){
  local ip="$1"
  [[ -z "$ip" ]] && echo '{}'
  curl -fsS --max-time 4 "http://ip-api.com/json/$ip?fields=status,country,city,regionName" 2>/dev/null || echo '{}'
}

human_os(){
  if [[ -f /etc/os-release ]]; then . /etc/os-release; echo "${PRETTY_NAME:-$NAME}"; else echo "Linux"; fi
}

while true; do
  NOW="$(date +%s)"
  CPU="$(get_cpu_usage)"
  MODEL="$(get_cpu_model)"
  VENDOR="$(get_cpu_vendor)"
  CORES="$(get_cores)"
  THREADS="$(get_threads)"
  MHZ="$(get_mhz)"
  TOTAL_MEM="$(mem_total)"
  AVAIL_MEM="$(mem_available)"
  USED_MEM=$((TOTAL_MEM-AVAIL_MEM))
  [[ "$USED_MEM" -lt 0 ]] && USED_MEM=0
  RAM_PCT="$(awk -v u="$USED_MEM" -v t="$TOTAL_MEM" 'BEGIN{if(t<=0)print 0;else printf "%.2f",u*100/t}')"

  DTOTAL="$(disk_total)"; DUSED="$(disk_used)"
  [[ "$DTOTAL" =~ ^[0-9]+$ ]] || DTOTAL=0
  [[ "$DUSED" =~ ^[0-9]+$ ]] || DUSED=0
  DISK_PCT="$(awk -v u="$DUSED" -v t="$DTOTAL" 'BEGIN{if(t<=0)print 0;else printf "%.2f",u*100/t}')"

  IFACE="$(default_iface)"
  read -r RX TX < <(net_bytes "$IFACE")
  RX=${RX:-0}; TX=${TX:-0}
  sleep 1
  read -r RX2 TX2 < <(net_bytes "$IFACE")
  RX2=${RX2:-0}; TX2=${TX2:-0}
  RX_BPS=$(( (RX2-RX) * 8 ))
  TX_BPS=$(( (TX2-TX) * 8 ))
  [[ "$RX_BPS" -lt 0 ]] && RX_BPS=0
  [[ "$TX_BPS" -lt 0 ]] && TX_BPS=0
  LINK="$(iface_speed "$IFACE")"
  [[ -z "$LINK" ]] && LINK="Unknown"

  LOAD1="$(awk '{print $1}' /proc/loadavg)"
  CPU_COUNT="$(get_threads)"
  LOAD_PCT="$(awk -v l="$LOAD1" -v c="$CPU_COUNT" 'BEGIN{if(c<=0)c=1;v=l*100/c;if(v>100)v=100;printf "%.2f",v}')"

  PING_RAW="$(ping -n -c 2 -W 1 1.1.1.1 2>/dev/null || true)"
  PING="$(echo "$PING_RAW" | awk -F'/' '/rtt|round-trip/{print $5;exit}')"
  LOSS="$(echo "$PING_RAW" | awk -F',' '/packet loss/{gsub(/%/,"",$3);gsub(/ /,"",$3);print $3;exit}')"
  [[ -z "$PING" ]] && PING=0
  [[ -z "$LOSS" ]] && LOSS=100

  IP="$(public_ip)"
  LOC="$(location_json "$IP")"
  COUNTRY="$(echo "$LOC" | sed -n 's/.*"country":"\([^"]*\)".*/\1/p')"
  CITY="$(echo "$LOC" | sed -n 's/.*"city":"\([^"]*\)".*/\1/p')"
  REGION="$(echo "$LOC" | sed -n 's/.*"regionName":"\([^"]*\)".*/\1/p')"

  UPTIME="$(awk '{print int($1)}' /proc/uptime)"
  HOST="$(hostname)"
  OS="$(human_os)"
  KERNEL="$(uname -r)"
  ARCH="$(uname -m)"

  DATA="$(cat <<EOF
{"node_uuid":"$NODE_UUID","token":"$NODE_TOKEN","name":"${NODE_NAME:-$HOST}","hostname":"$HOST","location_country":"$COUNTRY","location_city":"$CITY","region":"$REGION","network_name":"${NETWORK_NAME:-}","cpu_model":"$MODEL","cpu_vendor":"$VENDOR","cpu_cores":$CORES,"cpu_threads":$THREADS,"cpu_mhz":${MHZ:-0},"ram_total_bytes":$TOTAL_MEM,"storage_total_bytes":$DTOTAL,"os_name":"$OS","kernel":"$KERNEL","architecture":"$ARCH","ip_address":"$IP","cpu_usage":$CPU,"ram_used_bytes":$USED_MEM,"ram_percent":$RAM_PCT,"disk_used_bytes":$DUSED,"disk_percent":$DISK_PCT,"rx_bps":$RX_BPS,"tx_bps":$TX_BPS,"link_speed":"$LINK","ping_ms":$PING,"packet_loss":$LOSS,"uptime_seconds":$UPTIME,"load_avg":$LOAD1,"load_percent":$LOAD_PCT}
EOF
)"
  curl -fsS --max-time 8 -H 'Content-Type: application/json' -d "$DATA" "${MONITOR_URL%/}/api.php?action=heartbeat" >/dev/null 2>&1 || true
  sleep 1
done
