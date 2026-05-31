# IKEv2 StrongSwan VPN с логином и паролем

Собрано под схему:

- сервер: Ubuntu 24.04;
- VPN: IKEv2 StrongSwan;
- авторизация клиента: EAP-MSCHAPv2, логин и пароль;
- клиентский сертификат не нужен;
- серверный сертификат: Let's Encrypt RSA 4096;
- Windows-клиент: встроенный IKEv2 VPN.

## Быстрый запуск

```bash
sudo apt update
sudo apt install -y unzip

unzip ikev2_strongswan_scripts.zip
cd ikev2_strongswan_scripts

cp config.env.example config.env
nano config.env
chmod +x *.sh

sudo bash 08_run_all.sh
```

## Минимальный config.env

```env
DOMAIN="vpn.yuramishin.ru"
VPN_USER="yura"
VPN_PASSWORD=""
VPN_POOL="10.10.10.0/24"
VPN_DNS="1.1.1.1,8.8.8.8"
EXT_IF="auto"
STOP_NGINX_FOR_CERTBOT="1"
FORCE_CERT_RENEWAL="1"
```

Если `VPN_PASSWORD` пустой, скрипт спросит его интерактивно.

## Проверка

```bash
sudo bash 07_check_status.sh
sudo bash 09_watch_logs.sh
```

Ищи в логах:

```text
received EAP identity 'yura'
EAP method EAP_MSCHAPV2 succeeded
CHILD_SA ikev2-vpn established
```

## Windows

PowerShell от имени администратора:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\windows_client_setup.ps1
rasphone -d "Yura VPN"
```

Логин: `yura`

Пароль: тот, который указан в `/etc/ipsec.secrets`.

## Важные файлы

- `/etc/ipsec.conf`
- `/etc/ipsec.secrets`
- `/etc/ipsec.d/certs/server-cert.pem`
- `/etc/ipsec.d/private/server-key.pem`
- `/etc/ipsec.d/cacerts/le-chain-*.pem`
- `/etc/ufw/before.rules`
- `/etc/modprobe.d/dirtyfrag.conf`
- `/etc/modprobe.d/99-enable-ipsec.conf`
- `/etc/modules-load.d/ipsec.conf`

## Откат

Скрипт `01_reset_vpn.sh` делает бэкап в:

```text
/root/vpn-backup-YYYYMMDD-HHMMSS
```

Let's Encrypt сертификаты не удаляются.
