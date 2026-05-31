#!/usr/bin/env bash
set -Eeuo pipefail

log() {
  echo
  echo "==> $*"
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    die "Запусти от root: sudo bash $0"
  fi
}

load_config() {
  local config_file="${CONFIG_FILE:-./config.env}"

  if [[ -f "$config_file" ]]; then
    # shellcheck disable=SC1090
    source "$config_file"
  fi

  DOMAIN="${DOMAIN:-}"
  VPN_USER="${VPN_USER:-yura}"
  VPN_PASSWORD="${VPN_PASSWORD:-}"
  VPN_POOL="${VPN_POOL:-10.10.10.0/24}"
  VPN_DNS="${VPN_DNS:-1.1.1.1,8.8.8.8}"
  EXT_IF="${EXT_IF:-auto}"
  STOP_NGINX_FOR_CERTBOT="${STOP_NGINX_FOR_CERTBOT:-1}"
  FORCE_CERT_RENEWAL="${FORCE_CERT_RENEWAL:-1}"

  [[ -n "$DOMAIN" ]] || die "DOMAIN пустой. Создай config.env или передай DOMAIN=vpn.example.com"
}

detect_ext_if() {
  if [[ "${EXT_IF}" == "auto" || -z "${EXT_IF}" ]]; then
    EXT_IF="$(ip route show default | awk '{print $5; exit}')"
  fi

  [[ -n "${EXT_IF}" ]] || die "Не смог определить внешний интерфейс. Укажи EXT_IF в config.env"
}

require_password() {
  if [[ -z "${VPN_PASSWORD}" ]]; then
    read -r -s -p "VPN password for user ${VPN_USER}: " VPN_PASSWORD
    echo
  fi

  [[ -n "$VPN_PASSWORD" ]] || die "VPN_PASSWORD пустой"
}

backup_file() {
  local file="$1"
  local backup_dir="${2:-/root/vpn-backup-$(date +%Y%m%d-%H%M%S)}"

  if [[ -e "$file" ]]; then
    mkdir -p "$backup_dir"
    cp -a "$file" "$backup_dir/"
  fi
}

restart_if_active() {
  local service="$1"
  if systemctl list-unit-files | grep -q "^${service}.service"; then
    systemctl restart "$service" || true
  fi
}
