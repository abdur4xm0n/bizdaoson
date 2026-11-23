#!/usr/bin/env bash
# Saytni GitHub'dagi eng so'nggi versiyaga yangilash
#   sudo bash /opt/bizdaoson/deploy/yangilash.sh
set -euo pipefail
cd /opt/bizdaoson
git pull --ff-only
if ! cmp -s deploy/Caddyfile /etc/caddy/Caddyfile; then
  cp deploy/Caddyfile /etc/caddy/Caddyfile
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
  systemctl reload caddy
  echo "Caddy sozlamasi yangilandi."
fi
echo "Sayt yangilandi: $(git log -1 --format='%h %s')"
