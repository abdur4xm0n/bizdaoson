#!/usr/bin/env bash
# Saytni GitHub'dagi eng so'nggi versiyaga yangilash
#   sudo bash /opt/bizdaoson/deploy/yangilash.sh
# Sayt fayllari (site/) git pull bilan darhol yangilanadi.
# Veb-server sozlamasi o'zgargan bo'lsa, u ham ko'chiriladi (nginx yoki Caddy - qaysi biri ishlatilsa).
set -euo pipefail
cd /opt/bizdaoson
git pull --ff-only

NGINX_CONF=/etc/nginx/conf.d/bizdaoson.conf
if [[ -f $NGINX_CONF ]]; then
  if ! cmp -s deploy/nginx-bizdaoson.conf "$NGINX_CONF"; then
    cp "$NGINX_CONF" "/root/bizdaoson.conf.bak-$(date +%Y%m%d-%H%M%S)"
    cp deploy/nginx-bizdaoson.conf "$NGINX_CONF"
    if nginx -t 2>/dev/null; then
      systemctl reload nginx
      echo "nginx sozlamasi yangilandi."
    else
      nginx -t || true
      cp "$(ls -t /root/bizdaoson.conf.bak-* | head -1)" "$NGINX_CONF"
      echo "nginx sozlamasida xato - eski versiya qaytarildi."
      exit 1
    fi
  fi
elif systemctl is-active --quiet caddy 2>/dev/null; then
  if ! cmp -s deploy/Caddyfile /etc/caddy/Caddyfile; then
    cp deploy/Caddyfile /etc/caddy/Caddyfile
    caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile >/dev/null
    chown -R caddy:caddy /var/log/caddy
    systemctl reload caddy
    echo "Caddy sozlamasi yangilandi."
  fi
fi
echo "Sayt yangilandi: $(git log -1 --format='%h %s')"
