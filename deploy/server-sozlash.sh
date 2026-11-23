#!/usr/bin/env bash
# bizdaoson.uz serverini birinchi marta sozlash (Ubuntu 22.04 / 24.04, Debian 12)
#
# Ishlatish:
#   sudo git clone https://github.com/abdur4xm0n/bizdaoson.git /opt/bizdaoson
#   sudo bash /opt/bizdaoson/deploy/server-sozlash.sh
set -euo pipefail

LOYIHA=/opt/bizdaoson

if [[ $EUID -ne 0 ]]; then
  echo "Skriptni sudo bilan ishga tushiring: sudo bash $0"
  exit 1
fi
if [[ ! -f "$LOYIHA/site/index.html" ]]; then
  echo "Loyiha $LOYIHA papkasida topilmadi. Avval repozitoriyni o'sha yerga clone qiling."
  exit 1
fi

echo "==> 1/4 Caddy veb-serveri o'rnatilmoqda..."
if ! command -v caddy >/dev/null 2>&1; then
  apt-get update
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
else
  echo "    Caddy allaqachon o'rnatilgan: $(caddy version)"
fi

echo "==> 2/4 Sozlamalar ko'chirilmoqda..."
install -d -o caddy -g caddy /var/log/caddy
cp "$LOYIHA/deploy/Caddyfile" /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile

echo "==> 3/4 Brandmauer tekshirilmoqda..."
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80,443/tcp
fi

echo "==> 4/4 Caddy ishga tushirilmoqda..."
systemctl enable caddy
systemctl restart caddy
sleep 2
systemctl --no-pager --lines=5 status caddy || true

IP=$(curl -s --max-time 5 https://checkip.amazonaws.com || echo "SERVER_IP")
echo
echo "Tayyor!"
echo "Domen panelida DNS yozuvlari:  bizdaoson.uz -> A -> $IP"
echo "                               www.bizdaoson.uz -> A -> $IP"
echo "DNS ishlagach, HTTPS sertifikati avtomatik olinadi (1-2 daqiqa)."
echo "Tekshirish:  curl -I https://bizdaoson.uz/win"
