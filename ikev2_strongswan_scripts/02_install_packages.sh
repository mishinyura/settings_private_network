#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root

log "Обновляю apt и ставлю пакеты"
apt update

apt install -y \
  strongswan \
  strongswan-pki \
  libcharon-extra-plugins \
  libcharon-extauth-plugins \
  certbot \
  dnsutils \
  ufw \
  iptables \
  iproute2 \
  openssl

log "Ставлю linux-modules-extra для текущего ядра"
apt install -y "linux-modules-extra-$(uname -r)" || true

log "Готово"
