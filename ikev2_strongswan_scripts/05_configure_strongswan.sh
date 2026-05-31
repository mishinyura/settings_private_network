#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root
load_config
require_password

[[ -f "/etc/letsencrypt/live/${DOMAIN}/cert.pem" ]] || die "Нет cert.pem. Сначала запусти 03_issue_cert.sh"
[[ -f "/etc/letsencrypt/live/${DOMAIN}/chain.pem" ]] || die "Нет chain.pem. Сначала запусти 03_issue_cert.sh"
[[ -f "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]] || die "Нет privkey.pem. Сначала запусти 03_issue_cert.sh"

log "Останавливаю StrongSwan"
systemctl stop strongswan-starter 2>/dev/null || true
systemctl stop strongswan 2>/dev/null || true

log "Копирую сертификат, цепочку и ключ"
install -m 644 "/etc/letsencrypt/live/${DOMAIN}/cert.pem" /etc/ipsec.d/certs/server-cert.pem
install -m 600 "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" /etc/ipsec.d/private/server-key.pem

rm -f /etc/ipsec.d/cacerts/lets-encrypt-chain.pem
rm -f /etc/ipsec.d/cacerts/le-chain-*.pem

awk '
/BEGIN CERTIFICATE/ { n++ }
n > 0 { print > sprintf("/etc/ipsec.d/cacerts/le-chain-%02d.pem", n) }
' "/etc/letsencrypt/live/${DOMAIN}/chain.pem"

chmod 644 /etc/ipsec.d/cacerts/le-chain-*.pem

log "Проверяю, что cert и key совпадают"
CERT_MD5="$(openssl x509 -noout -modulus -in /etc/ipsec.d/certs/server-cert.pem | openssl md5 | awk '{print $2}')"
KEY_MD5="$(openssl rsa -noout -modulus -in /etc/ipsec.d/private/server-key.pem | openssl md5 | awk '{print $2}')"

echo "cert md5: $CERT_MD5"
echo "key  md5: $KEY_MD5"

[[ "$CERT_MD5" == "$KEY_MD5" ]] || die "Сертификат и ключ не совпадают"

log "Пишу /etc/ipsec.conf"
cat > /etc/ipsec.conf <<EOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn ikev2-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no

    left=%any
    leftid=@${DOMAIN}
    leftcert=server-cert.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0

    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=${VPN_POOL}
    rightdns=${VPN_DNS}
    rightsendcert=never
    eap_identity=%identity

    ike=aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha256-modp2048,aes128-sha1-modp1024!
    esp=aes256-sha256-modp2048,aes256-sha1-modp2048,aes128-sha256-modp2048,aes128-sha1-modp1024!
EOF

log "Пишу /etc/ipsec.secrets"
cat > /etc/ipsec.secrets <<EOF
: RSA "server-key.pem"

${VPN_USER} : EAP "${VPN_PASSWORD}"
EOF

chmod 600 /etc/ipsec.secrets

log "Отключаю xl2tpd, если он был"
systemctl stop xl2tpd 2>/dev/null || true
systemctl disable xl2tpd 2>/dev/null || true

log "Запускаю StrongSwan"
systemctl enable strongswan-starter
systemctl restart strongswan-starter
ipsec rereadall

log "Проверяю сертификаты StrongSwan"
ipsec listcerts
ipsec listcacerts

log "Статус"
ipsec statusall

log "Готово"
