#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root
load_config || true

BACKUP_DIR="/root/vpn-backup-$(date +%Y%m%d-%H%M%S)"
log "Делаю бэкап текущих VPN-конфигов в ${BACKUP_DIR}"

for f in \
  /etc/ipsec.conf \
  /etc/ipsec.secrets \
  /etc/strongswan.conf \
  /etc/ufw/before.rules \
  /etc/default/ufw \
  /etc/sysctl.conf \
  /etc/modprobe.d/dirtyfrag.conf \
  /etc/modprobe.d/99-enable-ipsec.conf \
  /etc/modules-load.d/ipsec.conf
do
  backup_file "$f" "$BACKUP_DIR"
done

log "Останавливаю старые VPN-сервисы"
systemctl stop strongswan-starter 2>/dev/null || true
systemctl stop strongswan 2>/dev/null || true
systemctl stop ipsec 2>/dev/null || true
systemctl stop xl2tpd 2>/dev/null || true
systemctl disable xl2tpd 2>/dev/null || true

log "Сбрасываю старые IPsec SA/policies"
ip xfrm state flush 2>/dev/null || true
ip xfrm policy flush 2>/dev/null || true

log "Убираю старые файлы StrongSwan, которые будут пересозданы"
rm -f /etc/ipsec.conf
rm -f /etc/ipsec.secrets
rm -f /etc/ipsec.d/certs/server-cert.pem
rm -f /etc/ipsec.d/private/server-key.pem
rm -f /etc/ipsec.d/cacerts/lets-encrypt-chain.pem
rm -f /etc/ipsec.d/cacerts/le-chain-*.pem

log "Убираю managed-блок NAT из /etc/ufw/before.rules, если он был"
if [[ -f /etc/ufw/before.rules ]]; then
  sed -i '/^# BEGIN IKEV2 VPN NAT$/,/^# END IKEV2 VPN NAT$/d' /etc/ufw/before.rules
fi

log "Готово. Сертификаты Let's Encrypt не удалялись."
echo "Бэкап: ${BACKUP_DIR}"
