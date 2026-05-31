#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root
load_config

log "Проверяю DNS для ${DOMAIN}"
RESOLVED_IP="$(dig +short A "$DOMAIN" | tail -n 1 || true)"
SERVER_IP="$(ip -4 route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src") {print $(i+1); exit}}')"

echo "DNS ${DOMAIN}: ${RESOLVED_IP:-not found}"
echo "Server public/src IP: ${SERVER_IP:-unknown}"

if [[ -z "${RESOLVED_IP}" ]]; then
  die "DNS A-запись не найдена. Сначала направь ${DOMAIN} на IP сервера."
fi

WAS_NGINX_ACTIVE="0"
if [[ "${STOP_NGINX_FOR_CERTBOT}" == "1" ]] && systemctl is-active --quiet nginx 2>/dev/null; then
  WAS_NGINX_ACTIVE="1"
  log "Останавливаю nginx для certbot standalone"
  systemctl stop nginx
fi

CERTBOT_ARGS=(certonly --standalone --key-type rsa --rsa-key-size 4096 --preferred-chain "ISRG Root X1" -d "$DOMAIN" --agree-tos --register-unsafely-without-email --non-interactive)

if [[ "${FORCE_CERT_RENEWAL}" == "1" ]]; then
  CERTBOT_ARGS+=(--force-renewal)
fi

log "Выпускаю RSA-сертификат Let's Encrypt"
certbot "${CERTBOT_ARGS[@]}"

if [[ "$WAS_NGINX_ACTIVE" == "1" ]]; then
  log "Запускаю nginx обратно"
  systemctl start nginx
fi

log "Проверяю сертификат"
ls -la "/etc/letsencrypt/live/${DOMAIN}/"
openssl x509 -in "/etc/letsencrypt/live/${DOMAIN}/cert.pem" -noout -subject -issuer -dates

log "Готово"
