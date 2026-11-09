# Changelog / Değişiklik Günlüğü

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### v0.1.1.0 — 2026-11-09

**Added:**
- `Update-Components.bat` / `Tools/Update-Components.ps1` — user-scope updater for Python/pip, pipx itself and pipx-managed packages, and Node.js/npm global packages, with `-Check` dry-run, plan/result tables, `-ReportPath <file>` JSON report (schema v1, `check`/`execute`, `plan`/`result`), and `Scripts/Update-Components.bat -Check` argument forwarding.
- Static Pester coverage for `Update-Components.ps1` and `Update-Components.bat` launcher contract.

**Changed:**
- `Update-Components.ps1` detects pipx itself via `pipx --version` and pipx-managed packages via `pipx list --json` + `pip index versions`; upgrades pipx itself via `pipx upgrade pipx` and all pipx-managed packages via `pipx upgrade-all`. Component appears as `pipx` to match `pip`/`npm` naming.
- `Update-Components.ps1` winget detection uses a hybrid path (optional `Microsoft.WinGet.Client`, fixed-width table parsing, `--upgrade-available`) and resolves Python winget IDs via candidates/query fallback; unparseable target versions are reported honestly (`Unknown`) instead of claiming up-to-date.
- `Update-Components.ps1` pip target detection prefers `pip install --dry-run --ignore-installed --report` JSON and falls back to `pip index versions` parsing (verified on pip 26.x); `--use-feature=fast-deps` is not used on pip 26.x.
- `Update-Components.ps1` upgrades `npm` itself and upgrades each outdated global npm package to the latest available version via `npm install --global <pkg>@<latest>` (including major versions), then rechecks `npm outdated -g`; stale/ambiguous results are avoided by parsing `npm outdated -g --json` as an object keyed by package name.
- `Update-Components.ps1` console output is English-only and includes live checking progress markers (including `Node.js/winget`).
- Network-activity policy updated to list `WinGet-Upgrade.bat` and `Update-Components.bat` (via `Tools/Update-Components.ps1`) as the only exceptions; user-facing docs, architecture, and troubleshooting updated.

### Unreleased


Reliability and hardening release: one PowerShell engine per launcher, evidence-based Repair reporting, a modern DNS command, a seven-check local gate, and complete bilingual documentation.

**Added:**
- `Clear-DnsClientCache.bat` — flushes the DNS cache with the `Clear-DnsClientCache` cmdlet; replaces `IPConfig-FlushDNS.bat`, needs no elevation, and supports `/nopause`.
- `Bug-Report.ps1` filters — searchable text, System/Application toggles, date range, and dropdown checkbox lists for event IDs and providers, with a select-all control and live labels.
- `Tools/Invoke-Gate.ps1` — one local gate running the seven checks CI declares: Syntax, Whitespace, Mojibake, Commits, Pester, Hygiene, LinkCheck.
- `Tools/Check-Mojibake.ps1` — encoding gate for tracked files, commit messages, and JSON payloads; bundled Git hooks and CI text audits use it.
- `Tools/Install-Dependencies.ps1` — one host dependency setup command with `-Check` verification.
- Bilingual guides under `Docs/` (overview/setup, architecture, troubleshooting), repository policy and ownership files, pull request template, and local Git hooks.
- GitLab CI mirror, weekly Dependabot updates, scheduled release-text audit, and Pester suites for the repair, report, gate, encoding, dependency, and WinGet helpers.

**Changed:**
- `.bat` launchers resolve one PowerShell engine per run (`pwsh` app alias, `pwsh` from PATH, then Windows PowerShell 5.1) and reuse it for timestamps, BOM checks, workload, and drain calls.
- `Repair-Windows.bat` records per-stage start/end timestamps (UTC+03:00), exit codes, and elapsed milliseconds, then prints a nine-line summary, total time, and overall status; missing evidence reports `INDETERMINATE`, `net start` code 2 is accepted only when `sc query` reports the service running, and a DISM cleanup recommendation requires review.
- `Clear-DnsClientCache.bat` clears an inherited `NOPAUSE` variable before parsing `/nopause`.
- Link Check runs on Markdown pushes to `main` as well as weekly and on pull requests.
- The recommended PowerShell release is 7.6.9; setup documentation names the dependency manifest and keeps WinGet at user scope.
- Documentation and governance now cover the project layer, release deprecation, the full root-document set, and Türkiye-pinned timestamps.

**Removed:**
- `Scripts/IPConfig-FlushDNS.bat` — replaced by the UAC-free `Clear-DnsClientCache.bat`.

**Fixed:**
- Launcher timestamps no longer break when the PowerShell path contains `(` or `&`.
- The local gate fails when `actionlint` or `lychee` is missing instead of reporting a skipped check and exiting 0; its header now states that LinkCheck fetches URLs.
- `Invoke-Gate.Tests.ps1` maps every gate check to its workflow step and pins the workflow file set.
- `Repair-Windows.bat` exits `1` for every overall status except `SUCCESS` and `SUCCESS (restart required)`; its SFC output is decoded from UTF-16LE before being appended, eliminating NUL bytes in the log.
- `Bug-Report.ps1` writes reports as UTF-8 with BOM again, matching the v0.1.0.0 behavior.
- Documentation security posture, launcher claims, Turkish grammar, and Windows Update / WinGet guidance are corrected.

### v0.1.0.1 — 2026-10-23

Reliability and hardening release: one PowerShell engine per launcher, evidence-based Repair reporting, a modern DNS command, a seven-check local gate, and complete bilingual documentation.

First release: personal Windows maintenance script collection.

**Added:**
- `Repair-Windows.bat` — DISM + SFC + WinSxS maintenance (includes ResetBase).
- `Reset-Windows-Update.bat` — reset Windows Update components.
- `IPConfig-FlushDNS.bat` — flush DNS cache.
- `WinGet-Upgrade.bat` — upgrade all packages.
- `Bug-Report.ps1` — single-file daily/weekly/monthly HTML report engine (`-Period`).

**Infrastructure:**
- Each script creates its own `Logs/<Name>/` folder and keeps an `index.txt` run ledger.
- Console and log output are identical; logs are written as UTF-8 with BOM.
- `Logs/` contents stay out of version control.

---

<a id="tr"></a>

## Türkçe

### v0.1.1.0 — 2026-11-09

**Eklenen:**
- `Update-Components.bat` / `Tools/Update-Components.ps1` — Python/pip, pipx kendi kendine ve pipx yönetimli paketleri, ve Node.js/npm global paketleri için kullanıcı kapsamı güncelleyici; `-Check` kuru çalıştırma, plan/sonuç tabloları, `-ReportPath <dosya>` JSON raporu (şema v1, `check`/`execute`, `plan`/`result`) ve `.bat` bağımsız değişken iletimi.
- `Update-Components.ps1` ve başlatıcı sözleşmesi için statik Pester kapsamı.

**Değişen:**
- `Update-Components.ps1`, `pipx --version` ile pipx kendi kendini, `pipx list --json` + `pip index versions` ile pipx yönetimli paketleri algılar; pipx kendisini `pipx upgrade pipx`, tüm pipx yönetimli paketleri `pipx upgrade-all` ile yükseltir. Bileşen `pip`/`npm`'e uygun olarak `pipx` olarak görünür.
- Önerilen ve sabitlenen PowerShell satırı 7.6.9'dur; kurulum komutu bu tam sürümü winget'ten ister.
- `Update-Components.ps1` winget algılaması hibrit yol kullanır (opsiyonel `Microsoft.WinGet.Client`, sabit genişlikli tablo ayrıştırma, `--upgrade-available`) ve Python winget ID’lerini aday/sorgu fallback’iyle çözümler; ayrıştırılamayan hedef sürümler “güncel” iddia edilmez, `Unknown` olarak raporlanır.
- `Update-Components.ps1` pip hedef sürümü önce `pip install --dry-run --ignore-installed --report` JSON’una, sonra `pip index versions` ayrıştırmasına bakar (pip 26.x’te doğrulandı); pip 26.x’te `--use-feature=fast-deps` kullanılmaz.
- `Update-Components.ps1`, `npm install --global npm@latest` ile `npm`'yi yükseltir, ardından her eski global paketi `npm install --global <pkg>@<latest>` ile (major sürümler dahil) yükseltir ve `npm outdated -g`'yi yeniden kontrol eder; `npm outdated -g --json`'yi paket adına göre anahtarlı nesne olarak ayrıştırarak kararsız/belirsiz sonuçlardan kaçınır.
- `Update-Components.ps1` konsol çıktısı yalnızca İngilizce'dir ve canlı denetleme ilerleme işaretleri içerir (`Node.js/winget` dahil).
- Ağ etkinliği politikası yalnızca `WinGet-Upgrade.bat` ve `Update-Components.bat` (`Tools/Update-Components.ps1` aracılığıyla) istisnalarını listeler; ilgili dokümanlar güncellendi.

### Yayınlanmamış

### v0.1.0.1 — 2026-10-23

Güvenilirlik ve sağlamlaştırma sürümü: başlatıcı başına tek PowerShell motoru, kanıta dayalı Repair raporlaması, modern DNS komutu, yedi denetimli yerel geçit ve eksiksiz iki dilli belgeler.

**Eklenen:**
- `Clear-DnsClientCache.bat` — DNS önbelleğini `Clear-DnsClientCache` cmdlet'iyle temizler; `IPConfig-FlushDNS.bat` yerine geçer, yükseltme istemez ve `/nopause` destekler.
- `Bug-Report.ps1` süzgeçleri — aranabilir metin, Sistem/Uygulama anahtarları, tarih aralığı ve olay kimliği ile sağlayıcı için açılır onay kutusu listeleri; tümünü seç denetimi ve canlı etiketler içerir.
- `Tools/Invoke-Gate.ps1` — CI'nin bildirdiği yedi denetimi koşturan tek yerel geçit: Syntax, Whitespace, Mojibake, Commits, Pester, Hygiene, LinkCheck.
- `Tools/Check-Mojibake.ps1` — izlenen dosyalar, commit iletileri ve JSON yükleri için kodlama geçidi; paketlenmiş Git kancaları ve CI metin denetimleri bunu kullanır.
- `Tools/Install-Dependencies.ps1` — `-Check` doğrulamalı tek konak bağımlılık kurulum komutu.
- `Docs/` altında iki dilli kılavuzlar (genel bakış/kurulum, mimari, sorun giderme), depo politika ve sahiplik dosyaları, pull request şablonu ve yerel Git kancaları.
- GitLab CI eşi, haftalık Dependabot güncellemeleri, zamanlanmış sürüm metni denetimi ve repair, rapor, geçit, kodlama, bağımlılık ve WinGet yardımcıları için Pester paketleri.

**Değişen:**
- `.bat` başlatıcıları her koşuda tek bir PowerShell motoru çözer (`pwsh` uygulama diğer adı, PATH'teki `pwsh`, sonra Windows PowerShell 5.1) ve zaman damgası, BOM denetimi, iş yükü ve boşaltma çağrılarında onu yeniden kullanır.
- `Repair-Windows.bat` her aşama için başlangıç/bitiş zaman damgası (UTC+03:00), çıkış kodu ve geçen milisaniyeyi kaydeder; ardından dokuz satırlık özet, toplam süre ve genel durum yazar; eksik kanıt `INDETERMINATE` bildirir, `net start` kod 2 yalnızca `sc query` hizmeti çalışıyor gösterdiğinde kabul edilir ve DISM temizlik önerisi inceleme gerektirir.
- `Clear-DnsClientCache.bat`, `/nopause` bağımsız değişkenini ayrıştırmadan önce devralınan `NOPAUSE` değişkenini temizler.
- Link Check, haftalık ve pull request'lerin yanı sıra `main` üzerindeki Markdown push'larında da çalışır.
- Önerilen PowerShell sürümü 7.6.9'dir; kurulum belgeleri bağımlılık bildirimini adlandırır ve WinGet'i kullanıcı kapsamında tutar.
- Belgeler ve yönetişim artık proje katmanını, sürüm kullanımdan kaldırmayı, tam kök belge kümesini ve Türkiye saatine sabitlenmiş zaman damgalarını kapsar.

**Kaldırılan:**
- `Scripts/IPConfig-FlushDNS.bat` — yükseltme istemeyen `Clear-DnsClientCache.bat` ile değiştirildi.

**Düzeltilen:**
- PowerShell yolu `(` veya `&` içerdiğinde başlatıcı zaman damgaları artık bozulmaz.
- Yerel geçit, `actionlint` veya `lychee` eksikken atlanan denetim bildirip 0 ile çıkmak yerine başarısız olur; başlığı artık LinkCheck'in URL'leri getirdiğini belirtir.
- `Invoke-Gate.Tests.ps1`, her geçit denetimini iş akışı adımına eşler ve iş akışı dosya kümesini sabitler.
- `Repair-Windows.bat`, `SUCCESS` ve `SUCCESS (restart required)` dışındaki her genel durumda `1` ile çıkar; SFC çıktısı eklenmeden önce UTF-16LE'den çözülür ve günlükteki NUL baytları kaldırılır.
- `Bug-Report.ps1` raporları v0.1.0.0 davranışına uygun olarak yeniden UTF-8 BOM ile yazar.
- Belgelerde güvenlik duruşu, başlatıcı iddiaları, Türkçe dilbilgisi ve Windows Update / WinGet yönlendirmesi düzeltildi.

### v0.1.0.0 — 2026-09-16

İlk sürüm: kişisel Windows bakım betikleri koleksiyonu.

**Eklenen:**
- `Repair-Windows.bat` — DISM + SFC + WinSxS bakımı (ResetBase dahil).
- `Reset-Windows-Update.bat` — Windows Update bileşenlerini sıfırlama.
- `IPConfig-FlushDNS.bat` — DNS önbelleğini temizleme.
- `WinGet-Upgrade.bat` — toplu paket yükseltme.
- `Bug-Report.ps1` — tek dosyalık günlük/haftalık/aylık HTML rapor motoru (`-Period`).

**Altyapı:**
- Her betik kendi `Logs/<Ad>/` klasörünü açar, `index.txt` koşu dökümü tutar.
- Konsol ve günlük çıktısı birebir aynıdır; günlükler BOM'lu UTF-8 yazılır.
- `Logs/` içerikleri repoya girmez.
