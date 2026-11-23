<#
    bizdaoson.uz - kompyuter xizmatlari skripti
    Ochiq kod, MIT litsenziya.

    Menyu:              irm bizdaoson.uz/win | iex
    Diagnostika:        irm bizdaoson.uz/diag | iex
    Masofaviy yordam:   irm bizdaoson.uz/yordam | iex
    Tozalash:           irm bizdaoson.uz/tozalash | iex
    Yangilash:          irm bizdaoson.uz/yangilash | iex

    Tanlangan dasturlar:
        &([scriptblock]::Create((irm bizdaoson.uz/win))) -Dasturlar "Google.Chrome,7zip.7zip"
    Tayyor to'plam:
        &([scriptblock]::Create((irm bizdaoson.uz/win))) -Toplam asosiy

    Talab: Windows 10/11, PowerShell 5.1 yoki yangiroq.

    MUHIM: bu fayl faqat ASCII belgilardan iborat bo'lishi kerak
    (eski Windows'larda kodlash buzilmasligi uchun). O'zbekcha harflar
    uchun oddiy apostrof (') ishlatiladi.

    Sinov uchun muhit o'zgaruvchilari:
        BIZDAOSON_URL    - sayt manzili (standart: https://bizdaoson.uz)
        BIZDAOSON_TEST   - 1 bo'lsa: hech narsa o'zgartirilmaydi, savollarga "yo'q"
        BIZDAOSON_PAPKA  - diagnostika hisoboti saqlanadigan papka
#>
param(
    [string]$Dasturlar,
    [string]$Toplam,
    [switch]$Diagnostika,
    [switch]$Tozalash,
    [switch]$Yangilash,
    [switch]$Masofaviy,
    [switch]$YangiOyna
)

# Hammasi alohida blok ichida: foydalanuvchi sessiyasi o'zgaruvchilar bilan ifloslanmasin
& {
    $ErrorActionPreference = 'Continue'
    $ProgressPreference = 'SilentlyContinue'
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    } catch {}

    $S = @{
        Versiya     = '0.1.0'
        BaseUrl     = 'https://bizdaoson.uz'
        Telegram    = 'https://t.me/isroilovxk'
        Katalog     = $null
        KatalogXato = $false
        WingetQo    = $null
        Test        = [bool]$env:BIZDAOSON_TEST
    }
    if ($env:BIZDAOSON_URL) { $S.BaseUrl = $env:BIZDAOSON_URL.TrimEnd('/') }
    $IdNamuna = '^[A-Za-z0-9][A-Za-z0-9._+\-]*$'

    # ==================================================================
    # Yordamchi funksiyalar
    # ==================================================================
    function Write-Sarlavha([string]$Matn) {
        Write-Host ''
        Write-Host ('  ' + ('=' * 58)) -ForegroundColor DarkCyan
        Write-Host "    $Matn" -ForegroundColor Cyan
        Write-Host ('  ' + ('=' * 58)) -ForegroundColor DarkCyan
    }
    function Write-Ok([string]$M)   { Write-Host "  [+] $M" -ForegroundColor Green }
    function Write-Ogoh([string]$M) { Write-Host "  [!] $M" -ForegroundColor Yellow }
    function Write-Xato([string]$M) { Write-Host "  [x] $M" -ForegroundColor Red }
    function Write-Info([string]$M) { Write-Host "  [i] $M" -ForegroundColor Gray }

    function Show-Logo {
        $w = 58
        $t = "   bizdaoson.uz   |   kompyuter xizmatlari   |   v$($S.Versiya)"
        Write-Host ''
        Write-Host ('  +' + ('-' * $w) + '+') -ForegroundColor DarkCyan
        Write-Host ('  |' + $t.PadRight($w) + '|') -ForegroundColor Cyan
        Write-Host ('  +' + ('-' * $w) + '+') -ForegroundColor DarkCyan
    }

    function Wait-Enter {
        if ($S.Test) { return }
        [void](Read-Host "`n  Davom etish uchun Enter bosing")
    }

    # Ha/yo'q savol. Test rejimida doim "yo'q" - hech narsa o'zgarmaydi.
    function Read-Ha([string]$Savol) {
        if ($S.Test) { return $false }
        $j = Read-Host "  $Savol  [h = ha / Enter = yo'q]"
        return ($j -match '^\s*(h|ha)\s*$')
    }

    function Read-Tanlov([string]$Matn = 'Tanlang') {
        if ($S.Test) { return '0' }
        return ([string](Read-Host "`n  $Matn")).Trim()
    }

    function Protect-Html([string]$Matn) {
        return [System.Net.WebUtility]::HtmlEncode($Matn)
    }

    function Test-Ping([string]$Manzil, [int]$Ms = 2000) {
        try {
            $r = (New-Object System.Net.NetworkInformation.Ping).Send($Manzil, $Ms)
            if ($r.Status -eq 'Success') { return [int]$r.RoundtripTime }
        } catch {}
        return $null
    }

    function Test-Admin {
        $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }

    # Skriptni o'sha parametrlar bilan administrator oynasida qayta ochadi.
    function Start-AdminOyna {
        $qism = @()
        if ($Dasturlar)   { $qism += "-Dasturlar '$Dasturlar'" }
        if ($Toplam)      { $qism += "-Toplam '$Toplam'" }
        if ($Diagnostika) { $qism += '-Diagnostika' }
        if ($Tozalash)    { $qism += '-Tozalash' }
        if ($Yangilash)   { $qism += '-Yangilash' }
        if ($Masofaviy)   { $qism += '-Masofaviy' }
        $qism += '-YangiOyna'
        $argStr = $qism -join ' '

        if ($PSCommandPath) {
            $buyruq = "& '" + ($PSCommandPath -replace "'", "''") + "' $argStr"
        } else {
            $buyruq = "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; " +
                      "&([scriptblock]::Create((irm '$($S.BaseUrl)/win'))) $argStr"
        }
        if ($env:BIZDAOSON_URL) { $buyruq = "`$env:BIZDAOSON_URL='$($S.BaseUrl)'; $buyruq" }
        $kod = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($buyruq))
        try {
            Start-Process powershell.exe -Verb RunAs -ErrorAction Stop `
                -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $kod"
            Write-Ok "Administrator oynasi ochildi - ishni o'sha oynada davom ettiring."
            return $true
        } catch {
            return $false
        }
    }

    # ==================================================================
    # Dasturlar katalogi (apps.json)
    # ==================================================================
    function Get-Katalog {
        if ($S.Katalog) { return $S.Katalog }
        if ($S.KatalogXato) { return $null }
        # Fayldan ishga tushirilgan bo'lsa - yonidagi apps.json (ishlab chiqish uchun)
        if ($PSCommandPath) {
            $mahalliy = Join-Path (Split-Path -Parent $PSCommandPath) 'apps.json'
            if (Test-Path -LiteralPath $mahalliy) {
                try { $S.Katalog = Get-Content -LiteralPath $mahalliy -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
            }
        }
        if (-not $S.Katalog) {
            try { $S.Katalog = Invoke-RestMethod -Uri "$($S.BaseUrl)/apps.json" -TimeoutSec 20 -ErrorAction Stop } catch {}
        }
        if (-not $S.Katalog) {
            $S.KatalogXato = $true
            Write-Xato "Dasturlar ro'yxatini yuklab bo'lmadi. Internetni tekshiring."
        }
        return $S.Katalog
    }

    function Get-DasturNomi([string]$Id) {
        $k = Get-Katalog
        if ($k) {
            $d = $k.apps | Where-Object { $_.id -eq $Id } | Select-Object -First 1
            if ($d) { return $d.name }
        }
        return $Id
    }

    # ==================================================================
    # winget
    # ==================================================================
    function Confirm-Winget {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Ogoh "winget (Windows dastur menejeri) topilmadi. O'rnatilmoqda, 1-3 daqiqa kuting..."
            try {
                Install-PackageProvider -Name NuGet -Force -ErrorAction Stop | Out-Null
                Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery -ErrorAction Stop | Out-Null
                Import-Module Microsoft.WinGet.Client -ErrorAction Stop
                Repair-WinGetPackageManager -AllUsers -ErrorAction Stop | Out-Null
            } catch {
                Write-Xato "winget o'rnatilmadi: $($_.Exception.Message)"
            }
            $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                        [Environment]::GetEnvironmentVariable('Path', 'User')
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                Write-Xato "winget topilmadi. Microsoft Store'dan 'App Installer' dasturini o'rnating yoki kompyuterni qayta yoqib, yana urinib ko'ring."
                return $false
            }
            Write-Ok 'winget tayyor.'
        }
        if (-not $S.WingetQo) {
            $S.WingetQo = @('--accept-source-agreements', '--accept-package-agreements')
            try {
                $v = [version](((winget --version) | Select-Object -First 1) -replace '[^\d\.]', '')
                if ($v -ge [version]'1.4') { $S.WingetQo += '--disable-interactivity' }
            } catch {}
        }
        return $true
    }

    function Install-Dasturlar([string[]]$Idlar) {
        $Idlar = @($Idlar | Where-Object { $_ -match $IdNamuna } | Select-Object -Unique)
        if ($Idlar.Count -eq 0) { Write-Ogoh 'Hech qanday dastur tanlanmadi.'; return }
        if (-not (Confirm-Winget)) { return }

        $ok = @(); $bor = @(); $xato = @(); $qayta = $false
        $i = 0
        foreach ($id in $Idlar) {
            $i++
            $nomi = Get-DasturNomi $id
            Write-Host ''
            Write-Host ("  [{0}/{1}] {2} o'rnatilmoqda..." -f $i, $Idlar.Count, $nomi) -ForegroundColor Cyan
            $qo = @('install', '--id', $id, '--exact', '--source', 'winget', '--silent') + $S.WingetQo
            & winget @qo
            $kod = $LASTEXITCODE
            # -1978335189 = yangilanish yo'q, -1978335135 = allaqachon o'rnatilgan
            if ($kod -eq 0) { $ok += $nomi; Write-Ok "$nomi o'rnatildi." }
            elseif ($kod -eq -1978335189 -or $kod -eq -1978335135) { $bor += $nomi; Write-Info "$nomi allaqachon o'rnatilgan." }
            elseif ($kod -eq 3010 -or $kod -eq 1641) { $ok += $nomi; $qayta = $true; Write-Ok "$nomi o'rnatildi (qayta yoqish kerak)." }
            else { $xato += $nomi; Write-Xato ("{0} o'rnatilmadi (kod: {1})." -f $nomi, $kod) }
        }

        Write-Sarlavha 'Natija'
        if ($ok.Count)   { Write-Ok   ("O'rnatildi: " + ($ok -join ', ')) }
        if ($bor.Count)  { Write-Info ('Avvaldan bor edi: ' + ($bor -join ', ')) }
        if ($xato.Count) {
            Write-Xato ('Xato: ' + ($xato -join ', '))
            Write-Info "Qayta urinib ko'ring yoki ustaga murojaat qiling."
        }
        if ($qayta) { Write-Ogoh "Ba'zi dasturlar to'liq ishlashi uchun kompyuterni qayta yoqing." }
    }

    function Install-Toplam([string]$TId) {
        $k = Get-Katalog
        if (-not $k) { return }
        $t = $k.presets | Where-Object { $_.id -eq $TId } | Select-Object -First 1
        if (-not $t) { Write-Xato "To'plam topilmadi: $TId"; return }
        Write-Sarlavha $t.name
        Install-Dasturlar @($t.apps)
    }

    # Butun ro'yxatni ko'rsatib, raqamlar bo'yicha tanlatadi: "1,4,7-9"
    function Select-Royxat {
        $k = Get-Katalog
        if (-not $k) { return @() }
        $royxat = New-Object System.Collections.ArrayList
        foreach ($kat in $k.categories) {
            $ichida = @($k.apps | Where-Object { $_.cat -eq $kat.id })
            if ($ichida.Count -eq 0) { continue }
            Write-Host ''
            Write-Host "  $($kat.name)" -ForegroundColor Yellow
            foreach ($d in $ichida) {
                [void]$royxat.Add($d)
                Write-Host ('   {0,3}. {1,-22} {2}' -f $royxat.Count, $d.name, $d.desc) -ForegroundColor Gray
            }
        }
        $kirit = Read-Tanlov 'Raqamlarni kiriting (masalan: 1,4,7-9). Bekor qilish: Enter'
        $idlar = New-Object System.Collections.ArrayList
        foreach ($bo in ($kirit -split '[,\s]+')) {
            $raqamlar = @()
            if ($bo -match '^(\d+)-(\d+)$') { $raqamlar = [int]$Matches[1]..[int]$Matches[2] }
            elseif ($bo -match '^\d+$')    { $raqamlar = @([int]$bo) }
            foreach ($x in $raqamlar) {
                if ($x -ge 1 -and $x -le $royxat.Count) { [void]$idlar.Add($royxat[$x - 1].id) }
            }
        }
        return @($idlar | Select-Object -Unique)
    }

    function Show-DasturMenyu {
        $k = Get-Katalog
        if (-not $k) { Wait-Enter; return }
        while ($true) {
            Write-Sarlavha "Dasturlar o'rnatish"
            $n = 0
            foreach ($t in $k.presets) {
                $n++
                Write-Host ("   [{0}]  {1}" -f $n, $t.name) -ForegroundColor White
                $nomlar = @($t.apps | ForEach-Object { Get-DasturNomi $_ }) -join ', '
                Write-Host "        $nomlar" -ForegroundColor DarkGray
            }
            Write-Host ''
            Write-Host "   [R]  Ro'yxatdan o'zim tanlayman"
            Write-Host '   [S]  Saytda tanlash (brauzer ochiladi)'
            Write-Host '   [0]  Orqaga'
            $tanlov = Read-Tanlov
            if ($tanlov -eq '0' -or $tanlov -eq '') { return }
            if ($tanlov -match '^[Ss]$') { Start-Process "$($S.BaseUrl)/#dasturlar"; continue }
            if ($tanlov -match '^[Rr]$') {
                $idlar = @(Select-Royxat)
                if ($idlar.Count -gt 0) { Install-Dasturlar $idlar; Wait-Enter }
                continue
            }
            if ($tanlov -match '^\d+$' -and [int]$tanlov -ge 1 -and [int]$tanlov -le @($k.presets).Count) {
                $t = @($k.presets)[[int]$tanlov - 1]
                if (Read-Ha "'$($t.name)' o'rnatilsinmi?") { Install-Dasturlar @($t.apps); Wait-Enter }
            }
        }
    }

    # ==================================================================
    # Diagnostika - HTML hisobot
    # ==================================================================
    function Invoke-Diagnostika {
        Write-Sarlavha 'Kompyuter diagnostikasi'
        Write-Info "Ma'lumotlar yig'ilmoqda, 20-60 soniya kuting..."

        $D = @{ Bolim = ''; Q = (New-Object System.Collections.ArrayList); Tartib = (New-Object System.Collections.ArrayList) }
        function Set-Bolim([string]$Nomi) { $D.Bolim = $Nomi; [void]$D.Tartib.Add($Nomi) }
        function Add-Q([string]$Nom, $Qiymat, [string]$Holat = 'info') {
            $q = [string]$Qiymat
            if (-not $q) { $q = '-' }
            [void]$D.Q.Add([pscustomobject]@{ Bolim = $D.Bolim; Nom = $Nom; Qiymat = $q; Holat = $Holat })
        }

        $os = $null; $cs = $null

        # ---- Umumiy ----
        Set-Bolim 'Umumiy'
        try {
            $os   = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
            $cs   = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
            $bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
            $reg  = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
            $ver = $reg.DisplayVersion
            if (-not $ver) { $ver = $reg.ReleaseId }

            Add-Q 'Kompyuter nomi' $env:COMPUTERNAME
            $model = ([string]$cs.Model).Trim()
            $ishlab = ([string]$cs.Manufacturer).Trim()
            if ($ishlab -and $model -notlike "$ishlab*") { $model = "$ishlab $model" }
            Add-Q 'Ishlab chiqaruvchi / model' $model
            if ($bios) { Add-Q 'Seriya raqami' $bios.SerialNumber }

            $win = '{0} {1} (build {2}.{3}), {4}' -f $os.Caption, $ver, $os.BuildNumber, $reg.UBR, $os.OSArchitecture
            $h = 'ok'
            if ($os.Caption -match 'Windows (7|8|10)\b') {
                $h = 'warn'; $win += " - bu versiya uchun Microsoft yangilanishlari to'xtagan, Windows 11 tavsiya etiladi"
            } elseif ($os.Caption -match 'Windows 11' -and $os.Caption -match 'Home|Pro' -and $ver -in @('21H2', '22H2', '23H2', '24H2')) {
                $h = 'warn'; $win += " - bu versiya eskirgan, Windows Update orqali yangilang"
            }
            Add-Q 'Windows' $win $h
            Add-Q "O'rnatilgan sana" $os.InstallDate.ToString('dd.MM.yyyy')
            $up = (Get-Date) - $os.LastBootUpTime
            $h = 'info'
            $upMatn = '{0} kun {1} soat' -f [math]::Floor($up.TotalDays), $up.Hours
            if ($up.TotalDays -gt 14) { $h = 'warn'; $upMatn += ' - kompyuterni vaqti-vaqti bilan qayta yoqib turing' }
            Add-Q 'Uzluksiz ishlagan vaqti' $upMatn $h
        } catch { Add-Q 'Xato' $_.Exception.Message 'warn' }

        try {
            $lic = Get-CimInstance SoftwareLicensingProduct -ErrorAction Stop `
                -Filter "PartialProductKey IS NOT NULL AND ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f'" |
                Select-Object -First 1
            if ($lic -and $lic.LicenseStatus -eq 1) { Add-Q 'Faollashtirish' 'Faollashtirilgan' 'ok' }
            else { Add-Q 'Faollashtirish' 'Faollashtirilmagan' 'warn' }
        } catch {}

        # ---- Protsessor ----
        Set-Bolim 'Protsessor'
        try {
            $cpu = @(Get-CimInstance Win32_Processor -ErrorAction Stop)
            Add-Q 'Model' ($cpu[0].Name -replace '\s+', ' ').Trim()
            Add-Q 'Yadrolar / oqimlar' ('{0} / {1}' -f ($cpu | Measure-Object NumberOfCores -Sum).Sum, ($cpu | Measure-Object NumberOfLogicalProcessors -Sum).Sum)
            Add-Q 'Chastota' ('{0:N1} GHz' -f ($cpu[0].MaxClockSpeed / 1000))
            $yuk = [int]$cpu[0].LoadPercentage
            $h = 'ok'; if ($yuk -gt 85) { $h = 'warn' }
            Add-Q 'Hozirgi yuklama' "$yuk%" $h
        } catch { Add-Q 'Protsessor' "Ma'lumot olinmadi" 'info' }

        # ---- RAM ----
        Set-Bolim 'Operativ xotira (RAM)'
        try {
            if (-not $cs) { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop }
            if (-not $os) { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop }
            $jami = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
            $h = 'ok'; $izoh = ''
            if ($jami -lt 3.5) { $h = 'bad'; $izoh = ' - juda kam, kamida 8 GB tavsiya etiladi' }
            elseif ($jami -lt 7.5) { $h = 'warn'; $izoh = ' - 8 GB yoki undan ko''p tavsiya etiladi' }
            Add-Q 'Jami' ("{0} GB{1}" -f $jami, $izoh) $h
            $band = [math]::Round((1 - ($os.FreePhysicalMemory * 1KB) / $cs.TotalPhysicalMemory) * 100)
            $h = 'ok'; if ($band -gt 85) { $h = 'warn' }
            Add-Q 'Hozir band' "$band%" $h
            $mods = @(Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue)
            if ($mods.Count -gt 0) {
                # Ba'zi plankalar ishlab chiqaruvchini JEDEC kodi bilan beradi (masalan 80CE = Samsung)
                $jedec = @{ '80CE' = 'Samsung'; '00CE' = 'Samsung'; '80AD' = 'SK hynix'; '00AD' = 'SK hynix';
                            '802C' = 'Micron'; '002C' = 'Micron'; '859B' = 'Crucial'; '04CD' = 'G.Skill';
                            '029E' = 'Corsair'; '0198' = 'Kingston'; '04CB' = 'ADATA'; '8551' = 'Qimonda' }
                $pl = @($mods | ForEach-Object {
                    $mf = ([string]$_.Manufacturer).Trim()
                    if ($mf -match '^[0-9A-Fa-f]{4,}$') { $mf = $jedec[$mf.Substring(0, 4).ToUpper()] }
                    ('{0} GB {1} MHz {2}' -f ($_.Capacity / 1GB), $_.Speed, $mf).Trim()
                }) -join '; '
                Add-Q 'Plankalar' $pl
                $slot = (Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue | Measure-Object MemoryDevices -Sum).Sum
                if ($slot -gt 0) {
                    $h = 'info'; $m = "{0} ta slotdan {1} tasi band" -f $slot, $mods.Count
                    if ($slot -gt $mods.Count) { $m += " - RAM qo'shish mumkin" }
                    Add-Q 'Slotlar' $m $h
                }
            }
        } catch { Add-Q 'RAM' "Ma'lumot olinmadi" 'info' }

        # ---- Disklar ----
        Set-Bolim 'Disklar'
        try {
            $tizimDisk = $null
            try { $tizimDisk = (Get-Partition -DriveLetter ($env:SystemDrive.TrimEnd(':')) -ErrorAction Stop).DiskNumber } catch {}
            foreach ($pd in @(Get-PhysicalDisk -ErrorAction Stop | Sort-Object { [int]$_.DeviceId })) {
                $tur = [string]$pd.MediaType
                if ($tur -eq 'Unspecified' -or -not $tur) { $tur = "turi noma'lum" }
                $qiymat = '{0} - {1}, {2}, {3:N0} GB' -f $pd.FriendlyName, $tur, $pd.BusType, ($pd.Size / 1GB)
                $h = 'ok'
                if ([string]$pd.HealthStatus -ne 'Healthy') { $h = 'bad'; $qiymat += " - HOLATI YOMON ($($pd.HealthStatus)), ma'lumotlarni zaxiralang!" }
                try {
                    $rc = $pd | Get-StorageReliabilityCounter -ErrorAction Stop
                    $qo = @()
                    if ($rc.Temperature -gt 0) { $qo += "harorat $($rc.Temperature) C" }
                    if ($null -ne $rc.Wear -and $rc.Wear -gt 0) {
                        $qo += "eskirgan $($rc.Wear)%"
                        if ($rc.Wear -ge 80) { $h = 'bad' } elseif ($rc.Wear -ge 50 -and $h -eq 'ok') { $h = 'warn' }
                    }
                    if ($rc.PowerOnHours -gt 0) { $qo += "$($rc.PowerOnHours) soat ishlagan" }
                    if ($qo.Count) { $qiymat += ' (' + ($qo -join ', ') + ')' }
                } catch {}
                $nom = 'Disk ' + $pd.DeviceId
                if ("$($pd.DeviceId)" -eq "$tizimDisk") {
                    $nom += ' (tizim)'
                    if ([string]$pd.MediaType -eq 'HDD' -and $h -eq 'ok') {
                        $h = 'warn'; $qiymat += ' - SSD ga almashtirish kompyuterni ancha tezlashtiradi'
                    }
                }
                Add-Q $nom $qiymat $h
            }
        } catch { Add-Q 'Fizik disklar' "Ma'lumot olinmadi" 'info' }
        try {
            foreach ($ld in @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop)) {
                if (-not $ld.Size) { continue }
                $foiz = [math]::Round($ld.FreeSpace / $ld.Size * 100)
                $h = 'ok'
                if ($foiz -lt 5) { $h = 'bad' } elseif ($foiz -lt 15) { $h = 'warn' }
                Add-Q "$($ld.DeviceID) bo'limi" ("{0:N1} GB bo'sh / {1:N1} GB ({2}% bo'sh)" -f ($ld.FreeSpace / 1GB), ($ld.Size / 1GB), $foiz) $h
            }
        } catch {}

        # ---- Videokarta ----
        Set-Bolim 'Videokarta va ekran'
        try {
            foreach ($g in @(Get-CimInstance Win32_VideoController -ErrorAction Stop)) {
                $q = '{0} (drayver {1})' -f $g.Name, $g.DriverVersion
                if ($g.CurrentHorizontalResolution) { $q += ', ekran {0}x{1}' -f $g.CurrentHorizontalResolution, $g.CurrentVerticalResolution }
                $h = 'ok'
                if ($g.InfFilename -eq 'display.inf' -or $g.Name -match 'Basic Display|Standard VGA') {
                    $h = 'bad'; $q += " - videodrayver o'rnatilmagan!"
                }
                Add-Q 'Videokarta' $q $h
            }
        } catch { Add-Q 'Videokarta' "Ma'lumot olinmadi" 'info' }

        # ---- Batareya (noutbuklar) ----
        $bat = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        if ($bat.Count -gt 0) {
            Set-Bolim 'Batareya'
            Add-Q 'Zaryad' "$($bat[0].EstimatedChargeRemaining)%"
            try {
                $dizayn = (Get-CimInstance -Namespace root/wmi -ClassName BatteryStaticData -ErrorAction Stop | Select-Object -First 1).DesignedCapacity
                $toliq  = (Get-CimInstance -Namespace root/wmi -ClassName BatteryFullChargedCapacity -ErrorAction Stop | Select-Object -First 1).FullChargedCapacity
                if ($dizayn -gt 0 -and $toliq -gt 0) {
                    $sog = [math]::Min(100, [math]::Round($toliq / $dizayn * 100))
                    $h = 'ok'; $izoh = ''
                    if ($sog -lt 50) { $h = 'bad'; $izoh = " - batareyani almashtirish kerak" }
                    elseif ($sog -lt 70) { $h = 'warn'; $izoh = ' - batareya eskirgan' }
                    Add-Q "Sog'lomligi" ("{0}% (yangi holatiga nisbatan){1}" -f $sog, $izoh) $h
                }
            } catch { Add-Q "Sog'lomligi" "Aniqlab bo'lmadi" 'info' }
        }

        # ---- Tarmoq ----
        Set-Bolim 'Tarmoq'
        try {
            $virtual = 'Virtual|VirtualBox|VMware|Hyper-V|TAP-|Wintun|WireGuard|Loopback|Bluetooth'
            foreach ($a in @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch $virtual })) {
                $ip = @(Get-NetIPAddress -InterfaceIndex $a.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                        Where-Object { $_.IPAddress -notlike '169.254*' } | ForEach-Object { $_.IPAddress }) -join ', '
                Add-Q $a.Name ('{0}, {1}, IP: {2}' -f $a.InterfaceDescription, $a.LinkSpeed, $ip)
            }
        } catch {}
        $ping = Test-Ping '8.8.8.8'
        $dns = $false
        try { [void][System.Net.Dns]::GetHostAddresses('google.com'); $dns = $true } catch {}
        if ($null -ne $ping -and $dns) { Add-Q 'Internet' "Ishlayapti (ping $ping ms)" 'ok' }
        elseif ($dns)                 { Add-Q 'Internet' "Ishlayapti (ping o'tmadi)" 'ok' }
        elseif ($null -ne $ping)      { Add-Q 'Internet' 'Ulanish bor, lekin DNS ishlamayapti' 'bad' }
        else                          { Add-Q 'Internet' "Ulanish yo'q" 'warn' }

        # ---- Xavfsizlik ----
        Set-Bolim 'Xavfsizlik'
        try {
            $av = @(Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)
            if ($av.Count -gt 0) { Add-Q 'Antivirus' (@($av | ForEach-Object { $_.displayName } | Select-Object -Unique) -join ', ') 'ok' }
            else { Add-Q 'Antivirus' 'Topilmadi' 'bad' }
        } catch {}
        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            if ($mp.AntivirusEnabled) {
                $kun = [int]((Get-Date) - $mp.AntivirusSignatureLastUpdated).TotalDays
                $h = 'ok'; if ($kun -gt 7) { $h = 'warn' }
                Add-Q 'Windows Defender bazasi' "$kun kun oldin yangilangan" $h
                if (-not $mp.RealTimeProtectionEnabled) { Add-Q 'Real vaqt himoyasi' "O'chirilgan" 'warn' }
            }
        } catch {}
        try {
            $off = @(Get-NetFirewallProfile -ErrorAction Stop | Where-Object { -not $_.Enabled } | ForEach-Object { $_.Name })
            if ($off.Count -gt 0) { Add-Q 'Brandmauer (firewall)' ("O'chirilgan: " + ($off -join ', ')) 'warn' }
            else { Add-Q 'Brandmauer (firewall)' 'Yoqilgan' 'ok' }
        } catch {}
        try {
            $hf = Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
            if ($hf) {
                $kun = [int]((Get-Date) - $hf.InstalledOn).TotalDays
                $h = 'ok'; if ($kun -gt 60) { $h = 'warn' }
                Add-Q 'Oxirgi Windows yangilanishi' ('{0} ({1} kun oldin)' -f $hf.InstalledOn.ToString('dd.MM.yyyy'), $kun) $h
            }
        } catch {}

        # ---- Qurilmalar ----
        Set-Bolim 'Qurilmalar va drayverlar'
        try {
            $sabablar = @{ 1 = 'sozlanmagan'; 3 = 'drayver buzilgan'; 10 = 'ishga tushmadi'; 18 = "drayverni qayta o'rnatish kerak";
                           28 = "drayver o'rnatilmagan"; 31 = 'drayver yuklanmadi'; 43 = "Windows to'xtatib qo'ydi" }
            $muammo = @(Get-CimInstance Win32_PnPEntity -Filter 'ConfigManagerErrorCode <> 0' -ErrorAction Stop |
                        Where-Object { $_.ConfigManagerErrorCode -notin @(22, 45) })
            if ($muammo.Count -eq 0) { Add-Q 'Drayverlar' 'Barcha qurilmalar normal ishlayapti' 'ok' }
            else {
                foreach ($m in $muammo) {
                    $nom = $m.Name; if (-not $nom) { $nom = $m.DeviceID }
                    $sabab = $sabablar[[int]$m.ConfigManagerErrorCode]
                    if (-not $sabab) { $sabab = "xato kodi $($m.ConfigManagerErrorCode)" }
                    Add-Q 'Muammoli qurilma' "$nom - $sabab" 'bad'
                }
            }
        } catch {}

        # ---- So'nggi 7 kundagi hodisalar ----
        Set-Bolim "So'nggi 7 kun"
        $dan = (Get-Date).AddDays(-7)
        try {
            $n = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $dan } -ErrorAction Stop).Count
        } catch { $n = 0 }
        $h = 'ok'; $m = "Yo'q"
        if ($n -gt 0) { $h = 'warn'; $m = "$n marta - tok uzilishi, muzlash yoki qizib ketish bo'lishi mumkin" }
        Add-Q "Kutilmagan o'chishlar" $m $h
        try {
            $n = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $dan } -ErrorAction Stop).Count
        } catch { $n = 0 }
        $h = 'ok'; $m = "Yo'q"
        if ($n -gt 0) { $h = 'bad'; $m = "$n marta - drayver yoki apparat muammosi" }
        Add-Q "Ko'k ekran (BSOD)" $m $h
        try {
            # Level 1-3 = kritik/xato/ogohlantirish. Axborot (masalan Ntfs 98 "disk sog'lom") sanalmaydi.
            $n = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = @('disk', 'Ntfs', 'Microsoft-Windows-Ntfs'); Level = @(1, 2, 3); StartTime = $dan } -ErrorAction Stop |
                   Where-Object { $_.Id -in @(7, 11, 51, 55, 98, 153) }).Count
        } catch { $n = 0 }
        $h = 'ok'; $m = "Yo'q"
        if ($n -gt 0) { $h = 'bad'; $m = "$n ta - diskni tekshirish kerak, ma'lumotlarni zaxiralang" }
        Add-Q 'Disk xatolari' $m $h

        # ---- Avtozagruzka ----
        Set-Bolim 'Avtomatik ishga tushadigan dasturlar'
        try {
            $st = @(Get-CimInstance Win32_StartupCommand -ErrorAction Stop | ForEach-Object { $_.Name } | Select-Object -Unique)
            $h = 'ok'; $m = '{0} ta' -f $st.Count
            if ($st.Count -gt 12) { $h = 'warn'; $m += ' - juda ko''p, kompyuter sekin yonishi mumkin' }
            if ($st.Count -gt 0) { $m += ': ' + (($st | Select-Object -First 15) -join ', ') }
            Add-Q 'Dasturlar' $m $h
        } catch {}

        # ---- Xulosa ----
        $yomon = @($D.Q | Where-Object { $_.Holat -eq 'bad' })
        $ogoh  = @($D.Q | Where-Object { $_.Holat -eq 'warn' })
        if ($yomon.Count -gt 0) { $xulosa = "Jiddiy muammolar: $($yomon.Count) ta. Ustaga murojaat qilish tavsiya etiladi."; $xh = 'bad' }
        elseif ($ogoh.Count -gt 0) { $xulosa = "Kompyuter ishlayapti, lekin e'tibor talab qiladigan narsalar bor: $($ogoh.Count) ta."; $xh = 'warn' }
        else { $xulosa = 'Kompyuter yaxshi holatda.'; $xh = 'ok' }

        # ---- HTML ----
        $css = @'
*{box-sizing:border-box}body{margin:0;padding:24px 16px;background:#f3f5f9;color:#111827;font:15px/1.5 "Segoe UI",system-ui,sans-serif}
.w{max-width:920px;margin:0 auto}header{display:flex;flex-wrap:wrap;justify-content:space-between;align-items:flex-end;gap:8px 16px}
h1{font-size:22px;margin:0}.logo{font-weight:700;color:#1d4ed8;font-size:15px}.m{color:#6b7280;font-size:13px}
.x{padding:14px 18px;border-radius:12px;font-weight:600;margin:16px 0}
.x.ok,.b.ok{background:#dcfce7;color:#166534}.x.warn,.b.warn{background:#fef3c7;color:#92400e}.x.bad,.b.bad{background:#fee2e2;color:#991b1b}
section{background:#fff;border:1px solid #e5e7eb;border-radius:12px;margin:12px 0;overflow:hidden}
h2{font-size:14px;margin:0;padding:10px 16px;background:#f9fafb;border-bottom:1px solid #e5e7eb;text-transform:uppercase;letter-spacing:.04em;color:#374151}
table{width:100%;border-collapse:collapse}td{padding:9px 16px;border-bottom:1px solid #f1f5f9;vertical-align:top}
td.n{width:30%;color:#4b5563}tr:last-child td{border-bottom:0}
.b{display:inline-block;font-size:11px;font-weight:700;padding:2px 8px;border-radius:99px;margin-left:8px;white-space:nowrap}
footer{margin:24px 0 8px;text-align:center;color:#6b7280;font-size:13px}a{color:#1d4ed8}
@media (max-width:600px){td{display:block;width:auto!important;padding:6px 16px}td.n{padding-bottom:0;font-weight:600}}
@media print{body{background:#fff;padding:0}section{break-inside:avoid}}
'@
        $belgilar = @{ ok = 'Yaxshi'; warn = "E'tibor"; bad = 'Muammo' }
        $vaqt = Get-Date -Format 'dd.MM.yyyy HH:mm'
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.Append('<!doctype html><html lang="uz"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
        [void]$sb.Append("<title>Diagnostika - $(Protect-Html $env:COMPUTERNAME)</title><style>$css</style></head><body><div class=""w"">")
        [void]$sb.Append("<header><div><div class=""logo"">bizdaoson.uz</div><h1>Kompyuter diagnostikasi</h1></div>")
        [void]$sb.Append("<div class=""m"">$(Protect-Html $env:COMPUTERNAME) &middot; $vaqt</div></header>")
        [void]$sb.Append("<div class=""x $xh"">$(Protect-Html $xulosa)</div>")
        foreach ($b in $D.Tartib) {
            $qatorlar = @($D.Q | Where-Object { $_.Bolim -eq $b })
            if ($qatorlar.Count -eq 0) { continue }
            [void]$sb.Append("<section><h2>$(Protect-Html $b)</h2><table>")
            foreach ($q in $qatorlar) {
                $belgi = ''
                if ($belgilar.ContainsKey($q.Holat)) { $belgi = "<span class=""b $($q.Holat)"">$(Protect-Html $belgilar[$q.Holat])</span>" }
                [void]$sb.Append("<tr><td class=""n"">$(Protect-Html $q.Nom)</td><td>$(Protect-Html $q.Qiymat)$belgi</td></tr>")
            }
            [void]$sb.Append('</table></section>')
        }
        [void]$sb.Append("<footer>Hisobot <a href=""$($S.BaseUrl)"">bizdaoson.uz</a> bepul diagnostika skripti bilan yaratildi.<br>Yordam kerak bo'lsa, ustaga yozing: <a href=""$($S.Telegram)"">$($S.Telegram -replace '^https://', '')</a></footer></div></body></html>")

        $papka = [Environment]::GetFolderPath('Desktop')
        if ($env:BIZDAOSON_PAPKA) { $papka = $env:BIZDAOSON_PAPKA }
        if (-not $papka -or -not (Test-Path -LiteralPath $papka)) { $papka = $env:TEMP }
        $fayl = Join-Path $papka ('bizdaoson-diagnostika-{0}-{1}.html' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyyMMdd-HHmm'))
        [IO.File]::WriteAllText($fayl, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))

        # ---- Konsolga qisqa natija ----
        Write-Host ''
        foreach ($q in $yomon) { Write-Xato ('{0}: {1}' -f $q.Nom, $q.Qiymat) }
        foreach ($q in $ogoh)  { Write-Ogoh ('{0}: {1}' -f $q.Nom, $q.Qiymat) }
        Write-Host ''
        if ($xh -eq 'ok') { Write-Ok $xulosa } elseif ($xh -eq 'warn') { Write-Ogoh $xulosa } else { Write-Xato $xulosa }
        Write-Ok "Hisobot saqlandi: $fayl"
        Write-Info "Hisobotni ustaga Telegram orqali yuborishingiz mumkin: $($S.Telegram)"
        if (-not $S.Test) { Start-Process $fayl }
    }

    # ==================================================================
    # Tozalash
    # ==================================================================
    function Invoke-Tozalash([switch]$Sorab) {
        Write-Sarlavha 'Kompyuterni tozalash'
        $drv = $env:SystemDrive.TrimEnd(':')
        $oldin = (Get-PSDrive $drv).Free

        $yollar = New-Object System.Collections.ArrayList
        foreach ($u in @(Get-ChildItem "$env:SystemDrive\Users" -Directory -Force -ErrorAction SilentlyContinue)) {
            $t = Join-Path $u.FullName 'AppData\Local\Temp'
            if (Test-Path -LiteralPath $t) { [void]$yollar.Add($t) }
        }
        [void]$yollar.Add("$env:windir\Temp")
        foreach ($y in $yollar) {
            Write-Info "Tozalanmoqda: $y"
            Get-ChildItem -LiteralPath $y -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Info 'Windows Update keshi tozalanmoqda...'
        Stop-Service -Name wuauserv, bits -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath "$env:windir\SoftwareDistribution\Download" -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv, bits -ErrorAction SilentlyContinue

        Write-Info 'Savat (korzina) tozalanmoqda...'
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue

        $keyin = (Get-PSDrive $drv).Free
        $bosh = [math]::Max(0, $keyin - $oldin)
        Write-Ok ("Tozalandi. Bo'shagan joy: {0:N2} GB" -f ($bosh / 1GB))

        if ($Sorab -and (Read-Ha 'Chuqur tozalash ham bajarilsinmi? (Windows komponentlari, 10-30 daqiqa)')) {
            Dism.exe /Online /Cleanup-Image /StartComponentCleanup
            Write-Ok 'Chuqur tozalash tugadi.'
        }
    }

    # ==================================================================
    # Yangilash
    # ==================================================================
    function Invoke-Yangilash {
        Write-Sarlavha 'Dasturlarni yangilash'
        if (-not (Confirm-Winget)) { return }
        Write-Info 'Yangilanishlar tekshirilmoqda...'
        & winget upgrade --source winget --accept-source-agreements
        Write-Host ''
        Write-Info "Barcha dasturlar yangilanmoqda, bu biroz vaqt olishi mumkin..."
        $qo = @('upgrade', '--all', '--source', 'winget', '--silent') + $S.WingetQo
        & winget @qo
        Write-Ok 'Dasturlarni yangilash tugadi.'
        Write-Info 'Windows yangilanishlarini ham tekshiring: Sozlamalar > Windows Update.'
    }

    # ==================================================================
    # Tarmoq
    # ==================================================================
    function Test-Internet {
        Write-Sarlavha 'Internetni tekshirish'
        $gw = $null
        try {
            $gw = (Get-NetRoute -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop | Sort-Object RouteMetric | Select-Object -First 1).NextHop
        } catch {}
        if ($gw) {
            $p = Test-Ping $gw
            if ($null -ne $p) { Write-Ok "Router ($gw) javob beryapti: $p ms" }
            else { Write-Ogoh "Router ($gw) ping'ga javob bermadi" }
        } else {
            Write-Xato 'Router topilmadi - kabel yoki Wi-Fi ulanishini tekshiring'
        }
        $p = Test-Ping '8.8.8.8'
        if ($null -ne $p) { Write-Ok "Internet bor: 8.8.8.8 - $p ms" }
        else { Write-Xato "8.8.8.8 ga ping o'tmadi" }
        try { [void][System.Net.Dns]::GetHostAddresses('google.com'); Write-Ok 'DNS ishlayapti' }
        catch { Write-Xato "DNS ishlamayapti - 'DNS keshini tozalash' ni sinab ko'ring" }
    }

    function Show-TarmoqMenyu {
        while ($true) {
            Write-Sarlavha 'Tarmoq va internet'
            Write-Host '   [1]  Internetni tekshirish'
            Write-Host '   [2]  DNS keshini tozalash (saytlar ochilmasa)'
            Write-Host "   [3]  Tarmoq sozlamalarini to'liq tiklash (qayta yoqish kerak)"
            Write-Host '   [0]  Orqaga'
            switch (Read-Tanlov) {
                '1' { Test-Internet; Wait-Enter }
                '2' { ipconfig /flushdns | Out-Null; Write-Ok 'DNS keshi tozalandi.'; Wait-Enter }
                '3' {
                    if (Read-Ha "Tarmoq sozlamalari tiklansinmi? Keyin kompyuterni qayta yoqish kerak bo'ladi") {
                        netsh winsock reset | Out-Null
                        netsh int ip reset | Out-Null
                        ipconfig /flushdns | Out-Null
                        Write-Ok 'Tayyor. Endi kompyuterni qayta yoqing.'
                    }
                    Wait-Enter
                }
                default { return }
            }
        }
    }

    # ==================================================================
    # Masofaviy yordam (RustDesk, ochiq kodli)
    # ==================================================================
    function Install-RustDesk {
        Write-Sarlavha 'Masofaviy yordam (RustDesk)'
        $exe = Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'
        if (-not (Test-Path -LiteralPath $exe)) {
            Write-Info 'RustDesk rasmiy GitHub sahifasidan yuklab olinmoqda...'
            try {
                $rel = Invoke-RestMethod 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' -Headers @{ 'User-Agent' = 'bizdaoson' } -TimeoutSec 30 -ErrorAction Stop
                $asset = $rel.assets | Where-Object { $_.name -match 'x86_64\.msi$' } | Select-Object -First 1
                if (-not $asset) { throw "o'rnatish fayli topilmadi" }
                $fayl = Join-Path $env:TEMP $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $fayl -UseBasicParsing -ErrorAction Stop
                Write-Info "O'rnatilmoqda..."
                $p = Start-Process msiexec.exe -ArgumentList "/i `"$fayl`" /qn /norestart" -Wait -PassThru
                Remove-Item -LiteralPath $fayl -Force -ErrorAction SilentlyContinue
                if ($p.ExitCode -notin @(0, 3010)) { throw "msiexec kodi $($p.ExitCode)" }
            } catch {
                Write-Xato "RustDesk o'rnatilmadi: $($_.Exception.Message)"
                return
            }
        }
        if (Test-Path -LiteralPath $exe) {
            Start-Process $exe
            Write-Ok 'RustDesk ochildi.'
            Write-Info "Oynadagi 'ID' raqami va parolni ustaga yuboring - usta kompyuteringizga ulanadi."
            Write-Info "Usta Telegram'da: $($S.Telegram)"
            Write-Info "Ulanishni to'xtatish uchun RustDesk oynasini yoping."
        } else {
            Write-Xato 'RustDesk topilmadi.'
        }
    }

    # ==================================================================
    # Asosiy menyu
    # ==================================================================
    function Show-AsosiyMenyu {
        while ($true) {
            if (-not $S.Test) { Clear-Host }
            Show-Logo
            Write-Host ''
            Write-Host "   [1]  Dasturlar o'rnatish"
            Write-Host '   [2]  Kompyuter diagnostikasi (hisobot)'
            Write-Host '   [3]  Tozalash (keraksiz fayllar)'
            Write-Host '   [4]  Barcha dasturlarni yangilash'
            Write-Host '   [5]  Tarmoq va internet'
            Write-Host '   [6]  Masofaviy yordam (usta ulanadi)'
            Write-Host ''
            Write-Host '   [0]  Chiqish'
            switch (Read-Tanlov) {
                '1' { Show-DasturMenyu }
                '2' { Invoke-Diagnostika; Wait-Enter }
                '3' { Invoke-Tozalash -Sorab; Wait-Enter }
                '4' { Invoke-Yangilash; Wait-Enter }
                '5' { Show-TarmoqMenyu }
                '6' { Install-RustDesk; Wait-Enter }
                '0' { return }
            }
        }
    }

    # ==================================================================
    # Kirish nuqtasi
    # ==================================================================
    if ($Dasturlar) {
        $idlar = @($Dasturlar -split '[,;\s]+' | Where-Object { $_ })
        $yomonId = @($idlar | Where-Object { $_ -notmatch $IdNamuna })
        if ($yomonId.Count -gt 0) { Write-Xato ("Noto'g'ri dastur nomi: " + ($yomonId -join ', ')); return }
        $Dasturlar = $idlar -join ','
    }
    if ($Toplam -and $Toplam -notmatch '^[a-z0-9\-]+$') { Write-Xato "Noto'g'ri to'plam nomi: $Toplam"; return }

    $amal = [bool]($Dasturlar -or $Toplam -or $Diagnostika -or $Tozalash -or $Yangilash -or $Masofaviy)
    $faqatDiag = [bool]($Diagnostika -and -not ($Dasturlar -or $Toplam -or $Tozalash -or $Yangilash -or $Masofaviy))

    if (-not (Test-Admin)) {
        if ($S.Test) {
            if (-not $faqatDiag) { Write-Ogoh "TEST: administrator huquqi kerak, to'xtatildi."; return }
        } else {
            Write-Info "Administrator huquqi kerak - ruxsat so'ralmoqda..."
            if (Start-AdminOyna) { return }
            if (-not $faqatDiag) {
                Write-Xato "Ruxsat berilmadi. PowerShell'ni 'Administrator sifatida' ochib, buyruqni qayta kiriting."
                return
            }
        }
        Write-Ogoh "Administrator huquqisiz ishlayapti - ba'zi ma'lumotlar chiqmasligi mumkin."
    }

    if (-not $amal) { Show-AsosiyMenyu; return }

    if ($Dasturlar)   { Write-Sarlavha "Dasturlar o'rnatish"; Install-Dasturlar ($Dasturlar -split ',') }
    if ($Toplam)      { Install-Toplam $Toplam }
    if ($Diagnostika) { Invoke-Diagnostika }
    if ($Tozalash)    { Invoke-Tozalash }
    if ($Yangilash)   { Invoke-Yangilash }
    if ($Masofaviy)   { Install-RustDesk }
    if ($YangiOyna)   { Wait-Enter }
}
