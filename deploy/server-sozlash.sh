#!/usr/bin/env bash
# bizdaoson.uz serverini birinchi marta sozlash
# Ishlaydi: Ubuntu 22.04/24.04, Debian 12, Amazon Linux 2023
#
# Ishlatish:
#   (Amazon Linux bo'lsa avval:  sudo dnf install -y git)
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

# 80/443 portlarini boshqa veb-server (masalan nginx) band qilgan bo'lsa - Caddy o'rnatilmaydi
band=$(ss -tlnpH '( sport = :80 or sport = :443 )' 2>/dev/null | grep -v caddy || true)
if [[ -n $band ]]; then
  echo "80/443 portlari boshqa dastur tomonidan band:"
  echo "$band"
  echo "Serverda nginx ishlayotgan bo'lsa, Caddy kerak emas:"
  echo "  sudo cp $LOYIHA/deploy/nginx-bizdaoson.conf /etc/nginx/conf.d/bizdaoson.conf"
  echo "  sudo nginx -t && sudo systemctl reload nginx"
  exit 1
fi

# Caddy'ni rasmiy GitHub relizidan o'rnatish (apt ombori bo'lmagan tizimlar uchun)
caddy_binar_ornatish() {
  local arch json ver v tmp asset
  case "$(uname -m)" in
    x86_64) arch=amd64 ;;
    aarch64) arch=arm64 ;;
    *) echo "Qo'llab-quvvatlanmaydigan arxitektura: $(uname -m)"; exit 1 ;;
  esac
  # Quvursiz (pipefail bilan "grep -m1" curl'ni yiqitadi) - versiyani bash regex bilan olamiz
  json=$(curl -fsSL https://api.github.com/repos/caddyserver/caddy/releases/latest)
  if [[ $json =~ \"tag_name\":[[:space:]]*\"(v[0-9][^\"]*)\" ]]; then
    ver=${BASH_REMATCH[1]}
  else
    echo "Caddy versiyasini aniqlab bo'lmadi"; exit 1
  fi
  v=${ver#v}
  asset="caddy_${v}_linux_${arch}.tar.gz"
  tmp=$(mktemp -d)
  echo "    Caddy $ver yuklab olinmoqda..."
  curl -fsSL -o "$tmp/$asset" "https://github.com/caddyserver/caddy/releases/download/${ver}/${asset}"
  curl -fsSL -o "$tmp/checksums.txt" "https://github.com/caddyserver/caddy/releases/download/${ver}/caddy_${v}_checksums.txt"
  echo "    Nazorat yig'indisi (SHA-512) tekshirilmoqda..."
  (cd "$tmp" && grep " ${asset}\$" checksums.txt | sha512sum -c -)
  tar -xzf "$tmp/$asset" -C "$tmp" caddy
  install -m 0755 "$tmp/caddy" /usr/bin/caddy
  rm -rf "$tmp"

  getent group caddy >/dev/null || groupadd --system caddy
  id caddy >/dev/null 2>&1 || useradd --system --gid caddy --create-home --home-dir /var/lib/caddy \
    --shell /usr/sbin/nologin --comment "Caddy web server" caddy
  mkdir -p /etc/caddy

  # Rasmiy systemd xizmati (caddyserver/dist dan)
  cat > /etc/systemd/system/caddy.service <<'UNIT'
[Unit]
Description=Caddy
Documentation=https://caddyserver.com/docs/
After=network.target network-online.target
Requires=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=/usr/bin/caddy run --environ --config /etc/caddy/Caddyfile
ExecReload=/usr/bin/caddy reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
}

echo "==> 1/4 Caddy veb-serveri o'rnatilmoqda..."
if command -v caddy >/dev/null 2>&1; then
  echo "    Caddy allaqachon o'rnatilgan: $(caddy version)"
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --batch --yes --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list
  chmod o+r /usr/share/keyrings/caddy-stable-archive-keyring.gpg /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y tar
  caddy_binar_ornatish
else
  echo "Bu tizim qo'llab-quvvatlanmaydi (apt yoki dnf kerak)."
  exit 1
fi

echo "==> 2/4 Sozlamalar ko'chirilmoqda..."
install -d -o caddy -g caddy /var/log/caddy
cp "$LOYIHA/deploy/Caddyfile" /etc/caddy/Caddyfile
if ! natija=$(caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile 2>&1); then
  echo "$natija"
  echo "Caddyfile'da xato bor - to'xtatildi."
  exit 1
fi
echo "    Caddyfile to'g'ri."
# validate root nomidan log faylini yaratib qo'yadi - egasini caddy'ga qaytaramiz
chown -R caddy:caddy /var/log/caddy

echo "==> 3/4 Brandmauer tekshirilmoqda..."
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow 80,443/tcp
elif command -v firewall-cmd >/dev/null 2>&1 && firewall-cmd --state >/dev/null 2>&1; then
  firewall-cmd --permanent --add-service=http --add-service=https
  firewall-cmd --reload
fi

echo "==> 4/4 Caddy ishga tushirilmoqda..."
systemctl enable caddy
systemctl restart caddy
sleep 2
if ! systemctl is-active --quiet caddy; then
  systemctl --no-pager --lines=15 status caddy || true
  echo "Caddy ishga tushmadi - yuqoridagi xatoni ko'ring."
  exit 1
fi
echo "    Caddy ishlayapti."

IP=$(curl -s --max-time 5 https://checkip.amazonaws.com || echo "SERVER_IP")
echo
echo "Tayyor!"
echo "Sinash (DNS'siz):   curl http://$IP/win"
echo "DNS yozuvlari:      bizdaoson.uz -> A -> $IP"
echo "                    www.bizdaoson.uz -> A -> $IP"
echo "DNS ishlagach, HTTPS sertifikati avtomatik olinadi (1-2 daqiqa)."
