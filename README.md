# bizdaoson.uz

Kompyuter xizmatlari: fleshkasiz, bitta buyruq bilan. Bepul va ochiq kodli.

Kompyuterda PowerShell'ni **administrator sifatida** oching (`Win + X` → *Terminal (Administrator)*) va yozing:

```powershell
irm bizdaoson.uz/win | iex
```

## Buyruqlar

| Buyruq | Nima qiladi |
|---|---|
| `irm bizdaoson.uz/win \| iex` | Asosiy menyu |
| `irm bizdaoson.uz/diag \| iex` | Diagnostika: ish stoliga HTML hisobot saqlaydi |
| `irm bizdaoson.uz/yordam \| iex` | Masofaviy yordam: RustDesk'ni o'rnatadi va ochadi |
| `irm bizdaoson.uz/tozalash \| iex` | Vaqtinchalik fayllar, Windows Update keshi va savatni tozalaydi |
| `irm bizdaoson.uz/yangilash \| iex` | Barcha dasturlarni yangilaydi (winget) |
| `&([scriptblock]::Create((irm bizdaoson.uz/win))) -Dasturlar "Google.Chrome,7zip.7zip"` | Tanlangan dasturlarni o'rnatadi (saytda tuziladi) |
| `&([scriptblock]::Create((irm bizdaoson.uz/win))) -Toplam asosiy` | Tayyor to'plamni o'rnatadi |

**Fayl yuborish:** [fayl.bizdaoson.uz](https://fayl.bizdaoson.uz) ([PairDrop](https://github.com/schlagmichdoch/PairDrop)) — kompyuter va telefon o'rtasida brauzer orqali, fleshkasiz. Bir Wi-Fi'dagi qurilmalar bir-birini o'zi ko'radi, boshqa joydagilar kod bilan ulanadi.

## Tuzilishi

```
site/                 <- serverda shu papka beriladi
  index.html          sayt
  style.css, app.js   dizayn va dastur tanlash
  apps.json           dasturlar katalogi (sayt ham, skript ham shundan o'qiydi)
  win.ps1             asosiy PowerShell skripti
  diag.ps1, yordam.ps1, tozalash.ps1, yangilash.ps1   qisqa buyruqlar
deploy/
  Caddyfile           veb-server sozlamasi (avtomatik HTTPS)
  server-sozlash.sh   serverni birinchi marta sozlash
  yangilash.sh        saytni GitHub'dan yangilash
```

## Yangi dastur qo'shish

1. ID'ni toping: `winget search telegram`
2. Tekshiring: `winget show --id Telegram.TelegramDesktop -e`
3. `site/apps.json` dagi `apps` ro'yxatiga qo'shing. Kerak bo'lsa, `presets` ichidagi to'plamga ham qo'shing.

Sayt ham, skript ham shu fayldan o'qiydi, boshqa joyni o'zgartirish shart emas.

## Kompyuterda sinab ko'rish

```powershell
# Sayt: http://localhost:8080
python -m http.server 8080 -d site

# Skript (administrator PowerShell'da). Fayldan ishga tushirilganda yonidagi apps.json o'qiladi
powershell -ExecutionPolicy Bypass -File .\site\win.ps1

# Xavfsiz sinov: hech narsa o'zgartirilmaydi, faqat diagnostika hisoboti yaratiladi
$env:BIZDAOSON_TEST = 1; $env:BIZDAOSON_PAPKA = "$env:TEMP"
powershell -ExecutionPolicy Bypass -File .\site\win.ps1 -Diagnostika
```

## Serverga joylash (AWS EC2)

1. **EC2 server:** Amazon Linux 2023 yoki Ubuntu 24.04. *Security group*da 80 va 443 portlarini hamma uchun oching. 22-portni (SSH) faqat o'z IP manzilingizga oching.
2. **Elastic IP** biriktiring, aks holda server qayta yonganda IP o'zgaradi.
3. Serverda:
   ```bash
   sudo dnf install -y git        # faqat Amazon Linux'da (Ubuntu'da git bor)
   sudo git clone https://github.com/abdur4xm0n/bizdaoson.git /opt/bizdaoson
   sudo bash /opt/bizdaoson/deploy/server-sozlash.sh
   ```
   Shundan keyin sayt IP orqali ochiladi: `http://SERVER_IP` va `irm SERVER_IP/win | iex`.

   **Serverda nginx allaqachon ishlayotgan bo'lsa** (boshqa saytlar bilan umumiy server), skript Caddy o'rnatmasdan to'xtaydi. Bu holda nginx sozlamasini qo'shing:
   ```bash
   sudo cp /opt/bizdaoson/deploy/nginx-bizdaoson.conf /etc/nginx/conf.d/bizdaoson.conf
   sudo nginx -t && sudo systemctl reload nginx
   ```
4. **DNS (Cloudflare):** `bizdaoson.uz` va `www` uchun A yozuvni server IP manziliga yo'naltiring.
   - Caddy bilan: **DNS only** (kulrang bulut). Caddy HTTPS sertifikatini o'zi oladi.
   - nginx bilan: **Proxied** (to'q sariq bulut), SSL/TLS rejimi **Full**.
5. Keyingi yangilanishlar uchun: `sudo bash /opt/bizdaoson/deploy/yangilash.sh`

Statistika (skriptni necha marta ishga tushirishgani):

```bash
sudo grep -c '"uri":"/win"' /var/log/caddy/bizdaoson.log
```

## Reja

- [x] **1-bosqich:** sayt, dastur o'rnatish, diagnostika, tozalash, yangilash, tarmoq, masofaviy yordam
- [x] **2-bosqich (1):** fayl yuborish: fayl.bizdaoson.uz (PairDrop, `deploy/pairdrop.service`, `deploy/nginx-fayl.conf`)
- [ ] **2-bosqich (2):** o'z RustDesk serverimiz, diagnostika hisobotini ustaga bir tugma bilan yuborish
- [ ] **3-bosqich:** Telegram bot va arizalar, ko'p kompyuterni boshqarish (MeshCentral), mahalliy dasturlar (E-IMZO va boshqalar)

## Qoidalar

- Faqat bepul yoki rasmiy litsenziyali dasturlar. **Crack, aktivator va o'zgartirilgan dasturlar qo'shilmaydi.**
- `win.ps1` faqat ASCII belgilardan iborat bo'lishi kerak, aks holda eski Windows'larda kodlash buziladi.
- Domen panelingiz, GitHub va server hisoblarida ikki bosqichli himoya (2FA) yoqilgan bo'lsin: kim domenni boshqarsa, o'sha odam `irm | iex` ishlatgan har bir kompyuterda istalgan kodni ishga tushira oladi.

## Litsenziya

MIT. Batafsil: [LICENSE](LICENSE).
