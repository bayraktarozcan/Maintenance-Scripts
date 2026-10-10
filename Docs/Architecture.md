# Architecture / Mimari

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

### Shared launcher harness

All four `.bat` files follow the same harness, verified by
`Tests/Bug-Report.Tests.ps1`:

1. Build a timestamp with `powershell -NoProfile` (`yyyyMMdd_HHmmss`).
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
  `AnalyzeComponentStore`.
- `Reset-Windows-Update.bat` (13 steps, needs admin): stop `wuauserv`,
  `bits`, `msiserver`, `cryptSvc`; delete `SoftwareDistribution` and
  `catroot2` contents; restart the services; `UsoClient StartScan`.
- `IPConfig-FlushDNS.bat` (1 step): `ipconfig /flushdns`.
- `WinGet-Upgrade.bat` (session probe + 3 steps): detects Standard vs elevated
  via `fltmc` verified against `whoami /groups` (`S-1-16-12288`), then runs
  `winget source update`, `winget upgrade --all --scope %SCOPE% ...`, and a
  list-only `winget upgrade --scope %SCOPE% ...`. Standard sessions use
  `--scope user`, elevated ones `--scope machine`; `WG_DRYRUN=1` prints
  steps 1-2 without running them. This is the only script with network
  activity (delegated to `winget`).

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
iskeleti izler:

1. `powershell -NoProfile` ile zaman damgası kur (`yyyyMMdd_HHmmss`).
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
  `AnalyzeComponentStore`.
- `Reset-Windows-Update.bat` (13 adım, yönetici ister): `wuauserv`,
  `bits`, `msiserver`, `cryptSvc` servislerini durdurma;
  `SoftwareDistribution` ve `catroot2` içeriklerini silme; servisleri
  yeniden başlatma; `UsoClient StartScan`.
- `IPConfig-FlushDNS.bat` (1 adım): `ipconfig /flushdns`.
- `WinGet-Upgrade.bat` (oturum saptama + 3 adım): `fltmc` ile Standart ve
  yükseltilmişi ayırır, `whoami /groups` (`S-1-16-12288`) ile doğrular;
  sonra `winget source update`, `winget upgrade --all --scope %SCOPE% ...`
  ve yalnızca listeleyen `winget upgrade --scope %SCOPE% ...` çalışır.
  Standart oturumlar `--scope user`, yükseltilmişler `--scope machine`
  kullanır; `WG_DRYRUN=1` 1-2. adımları çalıştırmadan yazar. Ağ
  etkinliği olan tek betik budur (`winget`'e delege edilir).

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
