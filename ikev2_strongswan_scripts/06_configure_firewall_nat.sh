#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root
load_config
detect_ext_if

log "Внешний интерфейс: ${EXT_IF}"

log "Включаю IPv4 forwarding"
cat > /etc/sysctl.d/99-ikev2-vpn.conf <<'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects=0
net.ipv4.conf.all.send_redirects=0
EOF

sysctl --system

log "Разрешаю forwarding в UFW"
sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw

log "Открываю порты"
ufw allow OpenSSH
ufw allow 500,4500/udp

log "Добавляю NAT managed-блок в /etc/ufw/before.rules"
[[ -f /etc/ufw/before.rules ]] || touch /etc/ufw/before.rules

sed -i '/^# BEGIN IKEV2 VPN NAT$/,/^# END IKEV2 VPN NAT$/d' /etc/ufw/before.rules

TMP_FILE="$(mktemp)"

cat > "$TMP_FILE" <<EOF
# BEGIN IKEV2 VPN NAT
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s ${VPN_POOL} -o ${EXT_IF} -m policy --pol ipsec --dir out -j ACCEPT
-A POSTROUTING -s ${VPN_POOL} -o ${EXT_IF} -j MASQUERADE
COMMIT

*mangle
:FORWARD ACCEPT [0:0]
-A FORWARD --match policy --pol ipsec --dir in -s ${VPN_POOL} -o ${EXT_IF} -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360
COMMIT
# END IKEV2 VPN NAT

EOF

cat /etc/ufw/before.rules >> "$TMP_FILE"
cat "$TMP_FILE" > /etc/ufw/before.rules
rm -f "$TMP_FILE"

log "Перезапускаю UFW"
ufw --force disable
ufw --force enable

log "Статус UFW"
ufw status verbose

log "NAT rules"
iptables -t nat -S | grep -E "${VPN_POOL}|MASQUERADE" || true

log "Готово"
