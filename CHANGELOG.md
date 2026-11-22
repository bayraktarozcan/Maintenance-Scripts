# Changelog / Değişiklik Günlüğü

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### Unreleased — 2026-11-22

Post-release fix and cleanup-mode choice: the execution report no longer collapses to an empty row when packages are updated, and `Repair-Windows.bat` asks which component-store cleanup mode to use.

**Changed:**
- `Repair-Windows.bat` now offers two startup modes: `1` Standard (`/StartComponentCleanup`) and `2` ResetBase (`/StartComponentCleanup /ResetBase`). Empty, invalid, or closed input selects Standard; ResetBase shows an explicit warning that existing update packages can no longer be uninstalled. The choice, warning, command line, and summary line are logged, so the selected mode is auditable. The previous flow always ran `/ResetBase` without asking.
- All five launchers now publish the workload exit code with `exit /b %EXITCODE%`. Multi-step launchers return 1 when any step fails. `Update-Components.bat` writes updater output to a scratch file instead of piping it, so the captured code is the updater's rather than the logger's.

**Fixed:**
- Script-scope `$result` assignments in the execution phase rebound `$script:Result` (PowerShell variable names are case-insensitive). The twelve-row result collector was replaced by an exit code, so every update run rendered `* : []` while still claiming success. Renamed those locals to `$commandExit` and the winget probe local to `$wingetStatus`.
- `Set-Result` now validates the collector before each update, and `Assert-ResultCollector` checks the complete twelve-row shape plus non-empty `Component`/`Status` fields before rendering. A broken collector fails closed instead of reporting success; the run terminates before rendering and before the JSON report, so `-ReportPath` writes no file in that failure mode and the `[ResultCollector]` error plus a nonzero exit are the CI signal.

**Added:**
- Executable Pester regression that extracts the collector and guard from source, reproduces the case-insensitive collision and asserts the guard rejects it; a static test forbids new generic `$result` assignments.
- `Tools/Check-LineEndings.ps1` and `Tools/Repair-LineEndings.ps1`: the local gate now has a `LineEndings` check that fails on mixed endings or on a working-tree ending that disagrees with the declared `eol` attribute; the repair tool changes only supplied or changed files and preserves BOM and encoding. `Tests/LineEndings.Tests.ps1` plants both defect classes in a throwaway git fixture, and the CI validate jobs mirror the check.
- GitHub `quality.yml` also runs the full Pester suite on `windows-latest`, so the five CMD-based cleanup-mode tests execute in CI instead of being skipped on Ubuntu. The Linux job keeps running every platform-neutral check.

### V0.1.1.2 — 2026-11-21

Post-release hardening: dotted versions compare numerically, the GitLab link check resolves its Rust tool from a verified release, and the bilingual documentation and mirror verifier no longer drift.

**Added:**
- `Tests/Update-Components.Tests.ps1` — host-tool coverage that extracts and runs `Compare-ToolVersion` from the updater source.
- `Tests/Invoke-Gate.Tests.ps1` — GitLab CI parity test: every gate job exists, images and Go tools stay on latest, and lychee never returns as a Go module.
- Two mirror-verifier fixtures for checklist items without a backticked anchor (18/18 cases).

**Changed:**
- `Tools/Update-Components.ps1` compares dotted versions component-wise with missing components read as zero, so winget's four-part version and PowerShell's three-part version agree (`7.7.0` equals `7.7.0.0`). An update is claimed only when the target is strictly newer.
- `Docs/Architecture.md` documents host tools, PowerShell 7, Pester, numeric version comparison, and `-ReportPath` in both languages.
- `Docs/Troubleshooting.md` is back to ten sections per language.
- `.gitignore` ignores Python bytecode cache (`__pycache__/`, `*.pyc`).

**Fixed:**
- `.gitlab-ci.yml` link check resolves the latest lychee release for the runner architecture, verifies its published SHA-256, and installs the binary; the previous `go install .../lychee` could never build a Rust tool.
- `Tools/Install-Dependencies.ps1` keeps `--exact` on the winget ID probe in `Install-Winget`, so a similarly named package cannot be mistaken for the intended one.
- `CHANGELOG.md` English sections were restored to full symmetry with the Turkish ones; the historical PowerShell 7.6.9 reference was corrected to 7.6.7.
- `Tools/verify_mirror.py` no longer compares prose for checklist items without a backticked anchor, so a correct translation cannot report false drift.
- `Docs/Troubleshooting.md` Turkish sections moved out of the English block; the missing English section was restored.

### V0.1.1.1 — 2026-11-21

Latest-version policy across CI and tooling: third-party actions resolve current code via default-branch refs, images and CLI tools track latest, host dependencies install at latest, and a mirror verifier with a fixture suite guards the bilingual AGENTS.md mirror.

**Added:**
- `Tools/verify_mirror.py` — developer-side mirror verifier: sync-sha plus structure parity (sections, heading depths, top-level rules, fences, tables, ordered checklist anchors), `--selftest` fixture suite, `--allow-missing` for CI; `Tests/Verify-Mirror.Tests.ps1` covers it.
- `Update-Components.ps1` also updates Pester, gitleaks, actionlint, lychee, and PowerShell 7 to latest alongside Python/pip/pipx/Node/npm.

**Changed:**
- Third-party GitHub Actions use their default branch (`@main`, `@master` where that is the default) instead of SHA pins; GitLab base images use `latest` tags and CLI tools use `go install @latest`; gitleaks resolves the latest release at run time with checksum verification.
- Host dependencies (`Install-Dependencies.ps1`, manifest, docs) install and report at latest instead of exact versions.
- `sha_pinning_required` is disabled for the repository; documented in AGENTS.md with the default-branch rationale.

**Fixed:**
- AGENTS.md CodeQL/auto-approve rules matched reality (GitHub default setup; no auto-approve workflow); stale "pinned" comments removed from CI files.
- Dependency tables and command docs no longer name retired exact versions.
- Markdown headings follow title case with fully uppercase abbreviations; a `Heading and abbreviation case` rule was added (code, anchors and literal strings untouched).
- Retired `IPConfig-FlushDNS.bat` name in the release-note template replaced with `Clear-DnsClientCache.bat`; dead local shortcut removed.

### V0.1.1.0 — 2026-11-09

**Added:**
- `Update-Components.bat` / `Tools/Update-Components.ps1` — user-scope updater for Python/pip, pipx itself and pipx-managed packages, and Node.js/npm global packages, with `-Check` dry-run, plan/result tables, `-ReportPath <file>` JSON report (schema v1, `check`/`execute`, `plan`/`result`), and `Scripts/Update-Components.bat -Check` argument forwarding.
- Static Pester coverage for `Update-Components.ps1` and `Update-Components.bat` launcher contract.

**Changed:**
- `Update-Components.ps1` detects pipx itself via `pipx --version` and pipx-managed packages via `pipx list --json` + `pip index versions`; upgrades pipx itself via `pipx upgrade pipx` and all pipx-managed packages via `pipx upgrade-all`. Component appears as `pipx` to match `pip`/`npm` naming.
- The recommended and pinned PowerShell line is 7.6.9; the setup command requests this exact version from winget.
- `Update-Components.ps1` winget detection uses a hybrid path (optional `Microsoft.WinGet.Client`, fixed-width table parsing, `--upgrade-available`) and resolves Python winget IDs via candidates/query fallback; unparseable target versions are reported honestly (`Unknown`) instead of claiming up-to-date.
- `Update-Components.ps1` pip target detection prefers `pip install --dry-run --ignore-installed --report` JSON and falls back to `pip index versions` parsing (verified on pip 26.x); `--use-feature=fast-deps` is not used on pip 26.x.
- `Update-Components.ps1` upgrades `npm` itself and upgrades each outdated global npm package to the latest available version via `npm install --global <pkg>@<latest>` (including major versions), then rechecks `npm outdated -g`; stale/ambiguous results are avoided by parsing `npm outdated -g --json` as an object keyed by package name.
- `Update-Components.ps1` console output is English-only and includes live checking progress markers (including `Node.js/winget`).
- Network-activity policy updated to list `WinGet-Upgrade.bat` and `Update-Components.bat` (via `Tools/Update-Components.ps1`) as the only exceptions; user-facing docs, architecture, and troubleshooting updated.

### V0.1.0.1 — 2026-10-23

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
- The recommended PowerShell release is 7.6.7; setup documentation names the dependency manifest and keeps WinGet at user scope.
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
- `Update-Components.ps1` `ConvertFrom-WingetTable` no longer returns empty rows when winget's separator line is one continuous run of dashes; column boundaries are now derived from the header line's whitespace gaps, and `Get-WingetPackageStatus` adds a regex fallback that extracts the Available version from raw output, so Node.js (and other packages) are detected instead of reporting `Unknown`.

### V0.1.0.0 — 2026-09-16

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

### Unreleased — 2026-11-22

Yayın sonrası düzeltme ve temizlik kipi seçimi: paket güncellendiğinde yürütme raporu artık boş satıra çökmüyor ve `Repair-Windows.bat` bileşen deposu temizlik kipini soruyor.

**Değişen:**
- `Repair-Windows.bat` artık açılışta iki kiş sunar: `1` Standart (`/StartComponentCleanup`) ve `2` ResetBase (`/StartComponentCleanup /ResetBase`). Boş, geçersiz veya kapalı girdide Standart seçilir; ResetBase, mevcut güncelleştirme paketleri artık kaldırılamayacağına dair açık uyarı gösterir. Seçim, uyarı, komut satırı ve özet satırı günlüğe yazılır; böylece hangi kipin kullanıldığı denetlenebilir. Önceki akış `/ResetBase` komutunu sormadan her zaman çalıştırıyordu.
- Beş başlatıcının tamamı iş yükü çıkış kodunu `exit /b %EXITCODE%` ile yayımlıyor. Çok adımlı başlatıcılar herhangi bir adım başarısız olduğunda 1 döndürüyor. `Update-Components.bat`, güncelleyici çıktısını pipe yerine geçici dosyaya yazıyor; böylece yakalanan kod logger'ın değil güncelleyicinin kodu oluyor.

**Düzeltildi:**
- Yürütme aşamasındaki betik kapsamındaki `$result` atamaları `$script:Result` dosyasını yeniden bağlıyordu (PowerShell değişken adları büyük/küçük harfe duyarsızdır). On iki satırlık sonuç toplayıcı bir çıkış koduna dönüşüyor, dolayısıyla her güncelleme çalışmasında başarı bildirilmesine karşın `* : []` basılıyordu. Bu yerel değişkenler `$commandExit`, winget sorgusu yereli ise `$wingetStatus` olarak yeniden adlandırıldı.
- `Set-Result` her güncellemeden önce toplayıcıyı doğruluyor; `Assert-ResultCollector` çizimden önce on iki satırlık tam yapıyı ve boş olmayan `Component`/`Status` alanlarını denetliyor. Bozulan toplayıcı artık başarı bildirmek yerine işlemi durduruyor; çalışma çizimden ve JSON raporundan önce sonlandığı için bu hata modunda `-ReportPath` dosya yazmıyor, CI sinyali `[ResultCollector]` hatası ve sıfırdan farklı çıkış kodudur.

**Eklendi:**
- Kaynaktan toplayıcıyı ve korumayı çıkarıp büyük/küçük harf çarpışmasını yeniden üreten ve korumanın reddini doğrulayan çalıştırılabilir Pester regresyon testi; yeni genel `$result` atamalarını yasaklayan statik test.
- `Tools/Check-LineEndings.ps1` ve `Tools/Repair-LineEndings.ps1`: yerel gate artık karışık satır sonlarını veya bildirilen `eol` özniteliğiyle uyuşmayan çalışma ağacı sonunu yakalayan `LineEndings` kontrolünü çalıştırıyor. Onarım aracı yalnızca verilen/değişen dosyalara dokunuyor, BOM ve kodlamayı koruyor. `Tests/LineEndings.Tests.ps1` geçici bir git fixture'ında iki hata sınıfını da ekleyip kontrolün düştüğünü kanıtlıyor; CI validate işleri kontrolü yansıtıyor.
- GitHub `quality.yml` artık Pester setini `windows-latest` üzerinde de çalıştırıyor; böylece `cmd` kullanan beş temizlik kipi testi Ubuntu'da atlanmak yerine CI'da gerçekten koşuyor. Linux job'u platform bağımsız kontrollerin tamamını çalıştırmaya devam ediyor.

### V0.1.1.2 — 2026-11-21

Yayın sonrası sağlamlaştırma: noktalı sürümler sayısal karşılaştırılır, GitLab bağlantı denetimi Rust aracını doğrulanmış sürümden çözümler ve iki dilli belgeler ile ayna doğrulayıcısı sapma üretmez.

**Eklenen:**
- `Tests/Update-Components.Tests.ps1` — güncelleyici kaynağından `Compare-ToolVersion` işlevini ayırıp çalıştıran ana makine aracı kapsamı.
- `Tests/Invoke-Gate.Tests.ps1` — GitLab CI eşlik testi: her geçit işi var, görüntüler ve Go araçları latest kalıyor, lychee bir Go modülü olarak geri dönmüyor.
- Çapası olmayan kontrol maddeleri için iki ayna doğrulayıcı fixture'ı (18/18 durum).

**Değişen:**
- `Tools/Update-Components.ps1` noktalı sürümleri bileşen bileşen karşılaştırır, eksik bileşenler sıfır sayılır; winget'in dört parçalı ve PowerShell'in üç parçalı sürümü böylece uyuşur (`7.7.0` ile `7.7.0.0` eşittir). Güncelleme yalnızca hedef kesin olarak daha yeniyse iddia edilir.
- `Docs/Architecture.md` iki dilde ana makine araçlarını, PowerShell 7'yi, Pester'ı, sayısal sürüm karşılaştırmasını ve `-ReportPath` seçeneğini belgeler.
- `Docs/Troubleshooting.md` her dilde on bölüme döndü.
- `.gitignore` Python bayt kodu önbelleğini (`__pycache__/`, `*.pyc`) yok sayar.

**Düzeltilen:**
- `.gitlab-ci.yml` bağlantı denetimi, koşucu mimarisi için en son lychee sürümünü çözer, yayımlanmış SHA-256'yı doğrular ve ikiliyi kurar; önceki `go install .../lychee` bir Rust aracını hiçbir zaman derleyemezdi.
- `Tools/Install-Dependencies.ps1`, `Install-Winget` içindeki winget kimlik sorgusunda `--exact` seçeneğini korur; benzer adlı bir paket hedef paketle karışmaz.
- `CHANGELOG.md` İngilizce bölümleri Türkçeleriyle tam simetrik olacak şekilde geri getirildi; tarihsel PowerShell 7.6.9 ifadesi 7.6.7 olarak düzeltildi.
- `Tools/verify_mirror.py`, çapası olmayan kontrol maddelerinin metnini artık karşılaştırmıyor; doğru bir çeviri yanlış sapma bildiremez.
- `Docs/Troubleshooting.md` Türkçe bölümleri İngilizce bloktan çıkarıldı; eksik İngilizce bölüm geri getirildi.

### V0.1.1.1 — 2026-11-21

CI ve araçlarda en güncel sürüm ilkesi: üçüncü taraf eylemler varsayılan dal referanslarıyla güncel kodu çözümler, görüntüler ve CLI araçları latest sürümleri izler, ana makine bağımlılıkları latest kurulur ve iki dilli AGENTS.md aynasını bir doğrulayıcı + fixture takımı korur.

**Eklenen:**
- `Tools/verify_mirror.py` — geliştirici tarafı ayna doğrulayıcısı: sync-sha + yapı eşleşmesi (bölümler, başlık derinlikleri, üst-düzey kurallar, fence'ler, tablolar, sıralı kontrol listesi anchor'ları), `--selftest` fixture takımı, CI için `--allow-missing`; `Tests/Verify-Mirror.Tests.ps1` kapsamı.
- `Update-Components.ps1` artık Python/pip/pipx/Node/npm yanında Pester, gitleaks, actionlint, lychee ve PowerShell 7'yi de latest'e günceller.

**Değişen:**
- Üçüncü taraf GitHub eylemleri SHA pin yerine varsayılan dalını (`@main`, depo varsayılanı `@master`) kullanır; GitLab taban görüntüleri `latest` etiketi, CLI araçları `go install @latest` kullanır; gitleaks çalışma zamanında en son sürümü çözüp sağlama toplamını doğrular.
- Ana makine bağımlılıkları (`Install-Dependencies.ps1`, bildirim, belgeler) tam sürüm yerine latest kurar/raporlar.
- Depo için `sha_pinning_required` kapatıldı; gerekçesi AGENTS.md'de yazılı.

**Düzeltilen:**
- AGENTS.md CodeQL/otomatik onay kuralları gerçeklikle uyumlu hale getirildi (GitHub varsayılan kurulumu; otomatik onay iş akışı yok); CI dosyalarındaki bayat "pinned" yorumları kaldırıldı.
- Bağımlılık tabloları ve komut belgeleri artık emekli olmuş tam sürümleri adlandırmıyor.
- Markdown başlıkları, kısaltmalar tamamen büyük harfle olacak şekilde başlık büyüklüğü kuralına uyarlandı; `Başlık ve kısaltma büyüklüğü` kuralı eklendi (kod, çapalar ve değişmez dizelere dokunulmadı).
- Yayın notu şablonundaki emekli `IPConfig-FlushDNS.bat` adı `Clear-DnsClientCache.bat` ile değiştirildi; ölü yerel kısayol kaldırıldı.

### V0.1.1.0 — 2026-11-09

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

### V0.1.0.1 — 2026-10-23

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
- Önerilen PowerShell sürümü 7.6.7'dir; kurulum belgeleri bağımlılık bildirimini adlandırır ve WinGet'i kullanıcı kapsamında tutar.
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
- `Update-Components.ps1`'deki `ConvertFrom-WingetTable`, winget'in ayıracı satırı tek bir çizgi olduğunda boş dizi döndürmüyor; sütun sınırları başlık satırındaki boşluklardan çıkarılıyor ve `Get-WingetPackageStatus` ham çıktının Available sürümünü regex ile çıkarmak için bir yedek ekledi, böylece Node.js ve diğer paketler `Unknown` yerine algılanıyor.

### V0.1.0.0 — 2026-09-16

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
