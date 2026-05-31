#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_lib.sh"

require_root

log "Ставлю linux-modules-extra для текущего ядра, если еще не стоит"
apt update
apt install -y "linux-modules-extra-$(uname -r)" || true

log "Убираю блокировку esp4 из dirtyfrag.conf, если она есть"
if [[ -f /etc/modprobe.d/dirtyfrag.conf ]]; then
  sed -i 's|^install esp4 /bin/false|# install esp4 /bin/false|' /etc/modprobe.d/dirtyfrag.conf
fi

log "Создаю override для IPsec-модулей"
cat > /etc/modprobe.d/99-enable-ipsec.conf <<'EOF'
install esp4 /sbin/modprobe --ignore-install esp4
install ah4 /sbin/modprobe --ignore-install ah4
EOF

log "Настраиваю автозагрузку IPsec-модулей"
cat > /etc/modules-load.d/ipsec.conf <<'EOF'
xfrm_user
xfrm_algo
af_key
esp4
ah4
authenc
cbc
aesni_intel
sha256_generic
EOF

depmod -a

log "Загружаю модули"
for m in xfrm_user xfrm_algo af_key esp4 ah4 authenc cbc aesni_intel sha256_generic; do
  modprobe "$m" 2>/dev/null || echo "WARN: not loaded: $m"
done

log "Текущие IPsec-модули"
lsmod | grep -E "esp4|ah4|xfrm|af_key|authenc|cbc|aes|sha256" || true

log "Проверяю modprobe rules"
modprobe -c | grep -E "^(install|blacklist) (esp4|ah4|xfrm)" || true

log "Готово"
