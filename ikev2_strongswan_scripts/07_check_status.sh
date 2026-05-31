#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root
load_config
detect_ext_if

echo
echo "== DNS =="
dig +short A "$DOMAIN" || true

echo
echo "== External interface =="
echo "$EXT_IF"
ip route show default || true

echo
echo "== StrongSwan service =="
systemctl status strongswan-starter --no-pager || true

echo
echo "== ipsec statusall =="
ipsec statusall || true

echo
echo "== certificates =="
ipsec listcerts || true
ipsec listcacerts || true

echo
echo "== modules =="
lsmod | grep -E "esp4|ah4|xfrm|af_key|authenc|cbc|aes|sha256" || true

echo
echo "== modprobe rules =="
modprobe -c | grep -E "^(install|blacklist) (esp4|ah4|xfrm)" || true

echo
echo "== sysctl =="
sysctl net.ipv4.ip_forward net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects || true

echo
echo "== ufw =="
ufw status verbose || true

echo
echo "== nat =="
iptables -t nat -S | grep -E "${VPN_POOL}|MASQUERADE" || true

echo
echo "== recent strongswan logs =="
journalctl -u strongswan-starter -n 120 --no-pager || true
