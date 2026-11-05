# Architecture / Mimari

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

### Shared launcher harness

All four `.bat` files follow the same harness, verified by
`Tests/Bug-Report.Tests.ps1`; `Tests/Repair-Windows.Tests.ps1` covers the
Repair-specific logging:

1. Resolve the PowerShell engine (the `pwsh` app alias under
   `%LOCALAPPDATA%\Microsoft\WindowsApps` when it exists and starts, otherwise
   `pwsh` from `PATH`, otherwise `powershell`), then build a timestamp with it
   (`yyyyMMdd_HHmmss`).
2. Resolve `Logs/<Name>/` next to the repo; fall back to
   `%TEMP%\<Name>` when the folder cannot be created.
3. Stamp the log file with a UTF-8 BOM and append the run to
   `index.txt` (the per-folder run ledger).
4. Run each numbered step to a `%TEMP%` scratch file, then mirror it to
   both the console (`type`) and the log file, so console and log output
   are identical. The scratch file is deleted afterwards.

### Per-script pipelines

- `Repair-Windows.bat` (9 steps, needs admin): DISM `CheckHealth`,
  `ScanHealth`, ensure `wuauserv`/`bits` are started, DISM
  `RestoreHealth`, `AnalyzeComponentStore`,
  `StartComponentCleanup /ResetBase`, `sfc /scannow`, final
  `AnalyzeComponentStore`. It also records an Istanbul start/end timestamp
  (`yyyy-MM-dd HH:mm:ss.fff`, UTC+03:00), exit code, and elapsed
  milliseconds for every step, then a nine-line summary and `TOTAL`. The
  overall status is `FAILED`, `REVIEW REQUIRED`, `INDETERMINATE`,
  `SUCCESS (restart required)`, or `SUCCESS`; missing evidence is never
  treated as success. The script exits `0` only for `SUCCESS` and
  `SUCCESS (restart required)`; every other overall status exits `1`.
  `sfc` output is decoded from UTF-16LE and appended as UTF-8, so the log
  contains no NUL bytes from that stage.
  DISM `3010` means restart required; a cleanup
  recommendation from `AnalyzeComponentStore` requires review; `net
  start` `2` is accepted only when `sc query` reports state `4` (running),
  a missing service is a failure, and any other state requires review;
  SFC `1` means review.
- `Reset-Windows-Update.bat` (13 steps, needs admin): stop `wuauserv`,
  `bits`, `msiserver`, `cryptSvc`; delete `SoftwareDistribution` and
  `catroot2` contents; restart the services; `UsoClient StartScan`.
- `Clear-DnsClientCache.bat` (1 step): `Clear-DnsClientCache`.
- `WinGet-Upgrade.bat` (2 steps): `winget source update`, then
  `winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements`.
  This script has network activity (delegated to `winget`).
- `Update-Components.bat` (launcher for `Tools/Update-Components.ps1`): resolves the PowerShell engine, sets up logging, forwards any arguments (including `-Check`), then calls the PS script which runs a two-phase update:
  1. **Detection phase**: checks `winget` for Python/Node.js runtime updates, `pip`/`npm` for package manager self-updates, `pip list --outdated --format=json` and `npm outdated -g --json` for global packages. Builds a plan table.
  2. **Execution phase**: applies updates and builds a result table. Runs entirely in user scope; never self-elevates. Supports `-Check` dry-run mode that shows the plan and exits.
  Network activity: `winget list --id`, `pip`/`npm` registry queries.

### Component updater engine

`Tools/Update-Components.ps1` implements a two-phase update pipeline with structured logging and plan/result tables:

**Phase 1 — Detection (Plan)**:
- Python runtime: `winget list --id Python.Python.X.Y --exact` → available version
- pip self: `pip install --upgrade --dry-run --ignore-installed --report` → JSON report for target version
- pip packages: `pip list --outdated --format=json` → array of `{name, version, latest_version}`
- Node.js runtime: `winget list --id OpenJS.NodeJS.LTS --exact` → available version
- npm self: `npm view npm@latest version` → latest version
- npm packages: `npm outdated -g --json` → array of `{name, current, wanted, latest}`
- Builds plan table with columns: Component, Action, Current, Target, Details

**Phase 2 — Execution (Result)**:
- Applies updates per plan: `winget upgrade --id ... --exact --accept-source-agreements --accept-package-agreements`, `pip install --upgrade <pkg>`, `npm update -g`
- Tracks before/after versions per component
- Builds result table with columns: Component, Status, Before, After
- Overall failure tracking; exits 0 on full success, 1 otherwise

**Conventions**:
- UTF-8 BOM logs under `Logs/Update-Components/` with `index.txt` ledger
- No elevation; all commands run in user scope
- `-Check` mode: runs Phase 1 only, shows plan, exits 0
- Winget "already up to date" negative exit codes treated as success
- npm warning exit codes (1 with `npm warn` output) treated as success

### Report engine

`Scripts/Bug-Report.ps1` (`-Period Daily|Weekly|Monthly`) reads Level-2
events from the System and Application logs via `Get-WinEvent`, excluding
the `Schannel` provider and IDs 36882/36888. Pure functions
(`Format-HtmlSafe`, `Get-ReportConfig`, `Clean-OldReports`,
`New-DarkHtmlReport`) are covered by Pester. Retention per period: Daily
keeps 30 reports (1-day window), Weekly keeps 4 (7-day window), Monthly
keeps 3 (30-day window). Output is a dark-themed, dependency-free HTML
file with client-side filters (provider, event ID, message text,
System/Application toggles). See
[Overview and Setup](Overview-And-Setup.md) for scheduling.

<a id="tr"></a>

## Türkçe

### Ortak başlatıcı iskeleti

Dört `.bat` dosyası da `Tests/Bug-Report.Tests.ps1` ile doğrulanan aynı
iskeleti izler; `Tests/Repair-Windows.Tests.ps1` Repair'a özgü günlüklemeyi
kapsar:

1. PowerShell motorunu çöz (`%LOCALAPPDATA%\Microsoft\WindowsApps` altındaki
   `pwsh` uygulama kısayolu varsa ve başlıyorsa onu, yoksa `PATH` üzerindeki
   `pwsh`'yi, o da yoksa `powershell`'i kullan) ve zaman damgasını
   (`yyyyMMdd_HHmmss`) bununla kur.
2. Deponun yanındaki `Logs/<Ad>/` klasörünü çöz; klasör açılamazsa
   `%TEMP%\<Ad>` yedeğine düş.
3. Günlük dosyasına UTF-8 BOM damgala ve koşuyu `index.txt`
   dosyasına işle (klasör başına koşu dökümü).
4. Numaralı her adımı `%TEMP%` altındaki geçici dosyaya çalıştır, sonra
   hem ekrana (`type`) hem günlüğe aynala; böylece ekran ve günlük
   çıktısı birebir aynı olur. Geçici dosya sonra silinir.

### Betik başına hatlar

- `Repair-Windows.bat` (9 adım, yönetici ister): DISM `CheckHealth`,
  `ScanHealth`, `wuauserv`/`bits` servislerinin çalıştığını sağlama, DISM
  `RestoreHealth`, `AnalyzeComponentStore`,
  `StartComponentCleanup /ResetBase`, `sfc /scannow`, son
  `AnalyzeComponentStore`. Ayrıca her adım için İstanbul saatine göre
  başlangıç/bitiş damgası (`yyyy-MM-dd HH:mm:ss.fff`, UTC+03:00), çıkış
  kodu ve geçen milisaniyeyi, ardından dokuz satırlık özet ve `TOTAL`
  satırını yazar. Genel durum `FAILED`, `REVIEW REQUIRED`,
  `INDETERMINATE`, `SUCCESS (restart required)` veya `SUCCESS` olur;
  eksik kanıt asla başarı sayılmaz. Betik yalnızca `SUCCESS` ve
  `SUCCESS (restart required)` için `0`, diğer tüm genel durumlarda `1`
  ile çıkar. `sfc` çıktısı UTF-16LE'den çözülüp UTF-8 olarak eklenir;
  böylece bu aşamadan günlüğe NUL baytı sızmaz.
  DISM `3010` yeniden başlatma;
  `AnalyzeComponentStore` temizlik önerisi inceleme gerektirir;
  `net start` `2` yalnızca `sc query` durumu `4` (çalışıyor)
  bildirdiğinde kabul edilir, eksik hizmet başarısız sayılır ve diğer
  durumlar inceleme gerektirir; SFC `1` inceleme anlamına gelir.
- `Reset-Windows-Update.bat` (13 adım, yönetici ister): `wuauserv`,
  `bits`, `msiserver`, `cryptSvc` servislerini durdurma;
  `SoftwareDistribution` ve `catroot2` içeriklerini silme; servisleri
  yeniden başlatma; `UsoClient StartScan`.
- `Clear-DnsClientCache.bat` (1 adım): `Clear-DnsClientCache`.
- `WinGet-Upgrade.bat` (2 adım): `winget source update`, sonra
  `winget upgrade --all --include-unknown --accept-source-agreements --accept-package-agreements`.
  Ağ etkinliği olan betiklerden biridir (`winget`'e delege edilir).
- `Update-Components.bat` (`Tools/Update-Components.ps1` başlatıcısı): PowerShell motorunu çözümler, günlüklemeyi kurar, bağımsız değişkenleri (`-Check` dâhil) iletir, PS betiğini çağırır. PS betiği iki aşamalı güncelleme çalıştırır:
  1. **Tespit aşaması**: Python/Node.js çalışma zamanı güncellemeleri için `winget list --id`, pip/npm için paket yöneticisi kendini-güncelleme, `pip list --outdated --format=json` ve `npm outdated -g --json` ile global paketler. Plan tablosu oluşturur.
  2. **Yürütme aşaması**: Güncellemeleri uygular ve sonuç tablosu oluşturur. Tamamen kullanıcı kapsamında koşur; asla kendini yükseltmez. `-Check` kuru çalıştırma (dry-run) modu planı gösterip çıkar.
  Ağ etkinliği: `winget list --id`, `pip`/`npm` kayıt sorguları.

### Bileşen güncelleyici motoru

`Tools/Update-Components.ps1` yapılandırılmış günlükleme ve plan/sonuç tabloları ile iki aşamalı güncelleme işlem hattı uygular:

**Aşama 1 — Tespit (Plan)**:
- Python çalışma zamanı: `winget list --id Python.Python.X.Y --exact` → mevcut sürüm
- pip kendisi: `pip install --upgrade --dry-run --ignore-installed --report` → JSON raporu hedef sürüm için
- pip paketleri: `pip list --outdated --format=json` → `{name, version, latest_version}` dizisi
- Node.js çalışma zamanı: `winget list --id OpenJS.NodeJS.LTS --exact` → mevcut sürüm
- npm kendisi: `npm view npm@latest version` → en son sürüm
- npm paketleri: `npm outdated -g --json` → `{name, current, wanted, latest}` dizisi
- Plan tablosu oluşturur: Bileşen, Eylem, Mevcut, Hedef, Detay sütunları

**Aşama 2 — Yürütme (Sonuç)**:
- Plan başına güncellemeleri uygular: `winget upgrade --id ... --exact --accept-source-agreements --accept-package-agreements`, `pip install --upgrade <pkg>`, `npm update -g`
- Bileşen başına önceki/sonraki sürümleri takip eder
- Sonuç tablosu oluşturur: Bileşen, Durum, Önceki, Sonraki sütunları
- Genel hata takibi; tam başarıda 0, aksi halde 1 ile çıkar

**Kurallar**:
- `Logs/Update-Components/` altına UTF-8 BOM'lu günlükler ve `index.txt` defteri
- Yükseltme yok; tüm komutlar kullanıcı kapsamında koşur
- `-Check` modu: sadece Aşama 1 çalışır, plan gösterilir, 0 ile çıkar
- Winget "zaten güncel" negatif çıkış kodları başarı sayılır
- npm uyarı çıkış kodları (1 + `npm warn` çıktısı) başarı sayılır

### Rapor motoru

`Scripts/Bug-Report.ps1` (`-Period Daily|Weekly|Monthly`), System ve
Application günlüklerindeki 2. düzey olayları `Get-WinEvent` ile okur;
`Schannel` sağlayıcısı ile 36882/36888 ID'leri dışlanır. Saf işlevler
(`Format-HtmlSafe`, `Get-ReportConfig`, `Clean-OldReports`,
`New-DarkHtmlReport`) Pester kapsamındadır. Dönem başına saklama: Daily
30 rapor (1 günlük pencere), Weekly 4 rapor (7 günlük pencere), Monthly
3 rapor (30 günlük pencere) tutar. Çıktı, istemci yanı süzgeçli
(sağlayıcı, olay ID'si, ileti metni, System/Application düğmeleri),
bağımlılıksız, koyu temalı HTML dosyasıdır. Zamanlama için
[Genel Bakış ve Kurulum](Overview-And-Setup.md) dosyasına bakın.
