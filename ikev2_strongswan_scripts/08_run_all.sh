#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "${SCRIPT_DIR}/00_lib.sh"
require_root
load_config
require_password

export DOMAIN VPN_USER VPN_PASSWORD VPN_POOL VPN_DNS EXT_IF STOP_NGINX_FOR_CERTBOT FORCE_CERT_RENEWAL

log "Старт полной установки IKEv2 StrongSwan"
bash ./01_reset_vpn.sh
bash ./02_install_packages.sh
bash ./03_issue_cert.sh
bash ./04_configure_kernel_modules.sh
bash ./05_configure_strongswan.sh
bash ./06_configure_firewall_nat.sh
bash ./07_check_status.sh

log "Готово. Теперь настрой Windows-клиент командами из windows_client_setup.ps1"
