# Architecture / Mimari

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

The product of this repository is the `Scripts/` directory — the maintenance launchers and the HTML report engine that users run. `Tools/` and `Tests/` are project components: developer/CI tooling and verification suites. Nothing here builds or bundles the product into `Scripts/`; it is shipped as-is.

### Shared Launcher Harness

All five `.bat` files follow the same harness, verified by
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
4. Run each numbered step and mirror it to both console and log. The
   DISM/SFC/net/winget launchers capture each step in a `%TEMP%` scratch file
   and `type` it afterwards. `Update-Components.bat` instead calls the
   updater directly with `-LogPath`; the updater appends every rendered line
   to the log as it prints it, so output is live and console colors survive.
5. Capture the workload exit code(s) and finish with `exit /b %EXITCODE%`,
   so a caller or scheduled task can detect failure. Launchers with several
   steps exit 1 when any step returned a nonzero code. `Update-Components.bat`
   invokes the updater directly, so the captured code is the updater's own.
6. Show the exit prompt with `pause` directly. `pause` already prints
   `Press any key to continue . . .` itself, so no key-drain loop
   (`KeyAvailable`/`ReadKey`) runs first. The message therefore appears
   immediately and a single press exits. All five launchers follow this rule.
   For download steps (`Update-Components` and `WinGet-Upgrade`), print a
   visible `Downloading: ...` line to both console and log before each
   installer; the output is buffered, so without it the screen stays silent
   for the whole download.

### Per-Script Pipelines

- `Repair-Windows.bat` (9 steps, needs admin): at startup it offers two modes:
  `1` Standard (`DISM /StartComponentCleanup`) and `2` ResetBase
  (`/StartComponentCleanup /ResetBase`). Empty, invalid, or closed input
  selects Standard; ResetBase shows an explicit warning because existing
  update packages can no longer be uninstalled. The choice, warning, and
  resulting command are written to both console and log. The nine steps are
  DISM `CheckHealth`, `ScanHealth`, ensure `wuauserv`/`bits` are started, DISM
  `RestoreHealth`, `AnalyzeComponentStore`, mode-dependent
  `StartComponentCleanup`, `sfc /scannow`, final
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
  1. **Detection phase**: checks `winget` for Python/Node.js runtime updates, `pip`/`npm` for package manager self-updates, `pip list --outdated --format=json` and `npm outdated -g --json` for global packages, and `pipx list --json` + `pip index versions` for pipx itself and pipx-managed packages. Prints one live line per component and closes with a total.
  2. **Execution phase**: applies updates and prints one live line per planned component, then closes with a total. Runs entirely in user scope; never self-elevates. Supports `-Check` dry-run mode that shows the plan lines and total, then exits.
  Output streams live: the launcher passes `-LogPath`, the updater appends every line to the log as it prints it, and console colors mark steps (cyan), update-available rows (magenta), successes (green), warnings (yellow), and errors (red). Phase 1 closes with the number of updates found and their component names; phase 2 closes with how many planned component updates were applied.
  Network activity: `winget list --id`, `pip`/`npm`/`pipx` registry queries.

### Component Updater Engine

`Tools/Update-Components.ps1` implements a two-phase update pipeline with structured logging, one live line per component, and a closing total per phase. The full plan/result data remains in the collectors and the JSON report:

**Phase 1 — Detection (Plan)**:
- Python runtime: `winget list --id Python.Python.X.Y --exact` → available version
- pip self: `pip install --upgrade --dry-run --ignore-installed --report` → JSON report for target version
- pip packages: `pip list --outdated --format=json` → array of `{name, version, latest_version}`
- pipx: `pipx list --json` → pipx itself and installed packages; `pip index versions <pkg>` → latest version; pipx packages live in isolated venvs and are invisible to `pip list --outdated`
- Node.js runtime: `winget list --id OpenJS.NodeJS.LTS --exact` → available version
- npm self: `npm view npm@latest version` → latest version
- npm packages: `npm outdated -g --json` → array of `{name, current, wanted, latest}`
- Host tools: `gitleaks`, `actionlint`, and `lychee` via `winget list --id <ID> --exact`; PowerShell 7 via `winget list --id Microsoft.PowerShell --exact` (latest 7.x); Pester via `Find-Module Pester` (PSGallery latest)
- Dotted versions are compared component-wise with missing components read as zero; an update is planned only when the target is strictly newer (`7.7.0` equals `7.7.0.0`)
- Prints one live line per component as soon as its check ends (`Set-Plan`), with action, current/target versions, and details. No closing plan table repeats those lines. Detected package names are printed once, at detection time, on indented lines (`Show-PlanItems`); the JSON report still carries the full `Items` arrays.
- Closes the phase with `1/2 Found N update(s): ...`, naming every component whose action is `Update available`; the actionable component lines and the closing line are magenta.

**Phase 2 — Execution (Result)**:
- Applies updates per plan: `winget upgrade --id ... --exact --accept-source-agreements --accept-package-agreements` for runtimes, host tools, and PowerShell 7; `Update-Module Pester -Force` for Pester; `pip install --upgrade <pkg>`; `pipx upgrade pipx` + `pipx upgrade-all`; `npm install --global npm@latest`; and `npm install --global <pkg>@<latest>` for outdated globals
- Tracks before/after versions per component
- Prints `Downloading: <component>...` (cyan) before each package-manager call (`Run-Command`), because child output is buffered to a string and would otherwise leave the screen silent during a long download; the raw command stays on the dim DEBUG line. `-Check` mode runs no installers and prints no download line.
- Prints a live result line only for components that had a planned update (`Set-Result`), using the same status colors as phase 1. Components that were already up to date were shown in phase 1 and are not printed again. No closing result table repeats those lines.
- Closes the phase with `2/2 X of Y component update(s) applied successfully`, counting only planned rows that ended `Updated` or `Up to date`; a partial or error row lowers the count and the line is yellow.
- Overall failure tracking; exits 0 on full success, 1 otherwise

**Conventions**:
- UTF-8 BOM logs under `Logs/Update-Components/` with `index.txt` ledger. The launcher stamps the BOM; the updater appends plain UTF-8 without a second one, so colors stay console-only and the log stays diffable.
- No elevation; all commands run in user scope
- `-Check` mode: runs Phase 1 only, prints the component lines and total, exits 0
- The result collector is a fixed twelve-row shape (`$script:ResultComponentNames` is its single source of truth). `Assert-ResultCollector` checks that shape and non-empty `Component`/`Status` fields before every `Set-Result` and before the final total; a violation throws and the run exits nonzero rather than reporting a misleading total. A violation terminates before the final total and before the JSON report is written, so `-ReportPath` produces no file in that failure mode: the `[ResultCollector]` error line and the nonzero exit code are the CI signal. Command exit codes are held in `$commandExit`, never `$result`, because PowerShell variable names are case-insensitive and a script-scope `$result` would rebind `$script:Result`.
- Winget "already up to date" negative exit codes treated as success
- npm warning exit codes (1 with `npm warn` output) treated as success
- `-ReportPath <file>` writes a UTF-8 JSON report (`schemaVersion` 1) with `mode`, `executionCompleted`, `host`, `plan`, `result`, `success`, and `exitCode`; `-Check -ReportPath ...` writes a check-mode report without applying changes

### Report Engine

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

Bu deponun ürünü `Scripts/` dizinidir — kullanıcıların çalıştırdığı bakım başlatıcıları ve HTML rapor motoru. `Tools/` ve `Tests/` proje bileşenleridir: geliştirici/CI araçları ve doğrulama paketleri. Ürün `Scripts/` içine derlenmez veya paketlenmez; olduğu gibi teslim edilir.

### Ortak Başlatıcı İskeleti

Beş `.bat` dosyası da `Tests/Bug-Report.Tests.ps1` ile doğrulanan aynı
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
4. Numaralı her adımı çalıştır ve hem ekrana hem günlüğe aynala.
   DISM/SFC/net/winget başlatıcıları her adımı `%TEMP%` altındaki geçici
   dosyaya yazıp sonra `type` eder. `Update-Components.bat` bunun yerine
   güncelleyiciyi `-LogPath` ile doğrudan çağırır; güncelleyici her satırı
   bastığı anda günlüğe de ekler, böylece çıktı canlı akar ve konsol
   renkleri korunur.
5. İş yükünün çıkış kodunu yakala ve `exit /b %EXITCODE%` ile bit; böylece
   çağıran işlem veya Zamanlayıcı başarısızlığı görebilir. Birden fazla
   adımı olan başlatıcı, herhangi bir adım sıfırdan farklı döndüğünde 1 ile
   çıkar. `Update-Components.bat` güncelleyiciyi doğrudan çağırdığı için
   yakalanan kod güncelleyicinin kendi kodudur.
6. Çıkış isteğini doğrudan `pause` ile göster; `pause` kendiliğinden
   `Press any key to continue . . .` mesajını bastığından önce bir tuş
   temizleme (`KeyAvailable`/`ReadKey`) döngüsü çalıştırılmaz. Böylece mesaj
   hemen görünür ve tek tuşla çıkılır. Beş başlatıcı da bu kuralı izler.
   İndirme yapan adımlarda (`Update-Components` ve `WinGet-Upgrade`) her
   indirme komutundan önce görünür bir `Downloading: ...` satırı hem ekrana
   hem günlüğe yazılır; çıktı tamponlandığı için bu satır olmasa kullanıcı
   uzun indirme boyunca sessiz bir ekran görür.

### Betik Başına Hatlar

- `Repair-Windows.bat` (9 adım, yönetici ister): açılışta iki kiş sunar:
  `1` Standart (`DISM /StartComponentCleanup`) ve `2` ResetBase
  (`/StartComponentCleanup /ResetBase`). Boş, geçersiz veya kapalı girdi
  Standart'ı seçer; ResetBase, mevcut güncelleştirme paketleri artık
  kaldırılamayacağı için açık uyarı gösterir. Seçim, uyarı ve oluşan komut
  hem ekrana hem günlüğe yazılır. Dokuz adım şunlardır: DISM `CheckHealth`,
  `ScanHealth`, `wuauserv`/`bits` servislerinin çalıştığını sağlama, DISM
  `RestoreHealth`, `AnalyzeComponentStore`, kipe bağlı
  `StartComponentCleanup`, `sfc /scannow`, son
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
  1. **Tespit aşaması**: Python/Node.js çalışma zamanı güncellemeleri için `winget list --id`, pip/npm için paket yöneticisi kendini-güncelleme, `pip list --outdated --format=json` ve `npm outdated -g --json` ile global paketler, `pipx list --json` + `pip index versions` ile pipx kendi kendine ve pipx yönetimli paketler. Her bileşen için tek canlı satır yazıp faz toplamıyla kapanır.
  2. **Yürütme aşaması**: Güncellemeleri uygular, planlanan her bileşen için tek canlı satır yazıp faz toplamıyla kapanır. Tamamen kullanıcı kapsamında koşur; asla kendini yükseltmez. `-Check` kuru çalıştırma (dry-run) modu bileşen satırlarını ve toplamı gösterip çıkar.
  Çıktı canlı akar: başlatıcı `-LogPath` iletir, güncelleyici her satırı bastığı anda günlüğe ekler; konsol renkleri adımları (camgöbeği), güncelleme bulunan satırları (macenta), başarıları (yeşil), uyarıları (sarı) ve hataları (kırmızı) işaretler. 1/2 aşaması bulunan güncelleme sayısı ve bileşen adlarıyla, 2/2 aşaması planlanan bileşen güncellemelerinden kaçının uygulandığıyla kapanır.
  Ağ etkinliği: `winget list --id`, `pip`/`npm`/`pipx` kayıt sorguları.

### Bileşen Güncelleyici Motoru

`Tools/Update-Components.ps1` yapılandırılmış günlükleme, bileşen başına tek canlı satır ve faz başına kapanış toplamı ile iki aşamalı güncelleme işlem hattı uygular. Tam plan/sonuç verisi toplayıcılarda ve JSON raporunda kalır:

**Aşama 1 — Tespit (Plan)**:
- Python çalışma zamanı: `winget list --id Python.Python.X.Y --exact` → mevcut sürüm
- pip kendisi: `pip install --upgrade --dry-run --ignore-installed --report` → JSON raporu hedef sürüm için
- pip paketleri: `pip list --outdated --format=json` → `{name, version, latest_version}` dizisi
- pipx: `pipx list --json` → pipx kendi kendine ve yüklü paketler; `pip index versions <pkg>` → en son sürüm; pipx paketleri izole ortamda yaşadığı için `pip list --outdated`'a görünmez
- Node.js çalışma zamanı: `winget list --id OpenJS.NodeJS.LTS --exact` → mevcut sürüm
- npm kendisi: `npm view npm@latest version` → en son sürüm
- npm paketleri: `npm outdated -g --json` → `{name, current, wanted, latest}` dizisi
- Ana makine araçları: `gitleaks`, `actionlint` ve `lychee` `winget list --id <ID> --exact` ile; PowerShell 7 `winget list --id Microsoft.PowerShell --exact` ile (en son 7.x); Pester `Find-Module Pester` ile (PSGallery en son)
- Noktalı sürümler bileşen bileşen karşılaştırılır; eksik bileşenler sıfır sayılır ve yalnızca hedef kesin olarak daha yeniyse güncelleme planlanır (`7.7.0` ile `7.7.0.0` eşittir)
- Her bileşenin kontrolü biter bitmez o bileşen için tek canlı satır yazı (`Set-Plan`): eylem, mevcut/hedef sürümler ve detaylar. Sonunda aynı satırları tekrarlayan plan tablosu yok. Tespit edilen paket adları yalnızca tespit anında girintili satırlarda yazılır (`Show-PlanItems`); JSON raporu tam `Items` dizilerini taşır.
- Aşamayı `1/2 Found N update(s): ...` satırıyla kapatır ve eylemi `Update available` olan her bileşeni adıyla sayar; eylem gerektiren bileşen satırları ve kapanış satırı macentadır.

**Aşama 2 — Yürütme (Sonuç)**:
- Plan başına güncellemeleri uygular: çalışma zamanları, ana makine araçları ve PowerShell 7 için `winget upgrade --id ... --exact --accept-source-agreements --accept-package-agreements`; Pester için `Update-Module Pester -Force`; `pip install --upgrade <pkg>`; `pipx upgrade pipx` + `pipx upgrade-all`; `npm install --global npm@latest`; eski kalan global paketler için `npm install --global <pkg>@<latest>`
- Bileşen başına önceki/sonraki sürümleri takip eder
- Her paket yöneticisi çağrısından önce `Downloading: <bileşen>...` (camgöbeği) satırı yazı (`Run-Command`); alt komut çıktısı bir diziye tamponlandığı için bu satır olmasa uzun indirme boyunca ekran sessiz kalır. Ham komut sönük DEBUG satırında kalır. `-Check` kipinde kurulum çalışmadığı için indirme satırı basılmaz.
- Yalnızca planlanmış güncellemesi olan bileşenler için canlı sonuç satırı yazı (`Set-Result`); 1/2'de zaten görülen güncel bileşenler tekrar basılmaz. Sonunda aynı satırları tekrarlayan sonuç tablosu yok.
- Aşamayı `2/2 X of Y component update(s) applied successfully` satırıyla kapatır; yalnızca `Updated` veya `Up to date` ile biten plan satırlarını sayar; kısmi veya hatalı satır sayıyı düşürür ve satır sarı olur.
- Genel hata takibi; tam başarıda 0, aksi halde 1 ile çıkar

**Kurallar**:
- `Logs/Update-Components/` altına UTF-8 BOM'lu günlükler ve `index.txt` defteri. BOM'u başlatıcı damgalar; güncelleyici ikinci bir BOM eklemeden düz UTF-8 yazar, böylece renkler yalnızca konsolda kalır ve günlük karşılaştırılabilir olur.
- Yükseltme yok; tüm komutlar kullanıcı kapsamında koşur
- `-Check` modu: sadece Aşama 1 çalışır, bileşen satırları ve toplam gösterilir, 0 ile çıkar
- Sonuç toplayıcı sabit on iki satırlık bir yapıdır (`$script:ResultComponentNames` tek doğruluk kaynağıdır). `Assert-ResultCollector` bu yapıyı ve boş olmayan `Component`/`Status` alanlarını her `Set-Result` çağrısından önce ve son toplamdan önce denetler; ihlal durumunda hata verilir ve çalışma yanıltıcı bir toplam basmak yerine sıfırdan farklı kodla çıkar. İhlal, son toplam ve JSON raporundan önce sonlandırır; bu hata modunda `-ReportPath` dosya üretmez, CI sinyali `[ResultCollector]` hata satırı ve sıfırdan farklı çıkış kodudur. Komut çıkış kodları `$commandExit` içinde tutulur, asla `$result` içinde değil; çünkü PowerShell değişken adları büyük/küçük harfe duyarsızdır ve betik kapsamındaki bir `$result`, `$script:Result` dosyasını yeniden bağlar.
- Winget "zaten güncel" negatif çıkış kodları başarı sayılır
- npm uyarı çıkış kodları (1 + `npm warn` çıktısı) başarı sayılır
- `-ReportPath <dosya>` UTF-8 JSON raporu (`schemaVersion` 1) yazar: `mode`, `executionCompleted`, `host`, `plan`, `result`, `success`, `exitCode`; `-Check -ReportPath ...` değişiklik uygulamadan check modu raporu yazar

### Rapor Motoru

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
