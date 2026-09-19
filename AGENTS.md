# AGENTS / AJANLAR

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

Guidance for AI coding agents working in this repository.

### Project

Personal Windows maintenance script collection: four `.bat` launchers plus a
PowerShell HTML report engine. `Bug-Report.ps1` is the only PowerShell logic;
the `.bat` files are thin wrappers around system tools (`DISM`, `SFC`,
`ipconfig`, `winget`). The `.bat` launchers run the tools inline and never pass
`-ExecutionPolicy Bypass`; they only invoke `powershell -NoProfile` to build
log timestamps. `Bug-Report.ps1` is called separately (e.g. scheduled task)
with `-NoProfile -ExecutionPolicy Bypass -File`.

### Ground rules

- Scripts must stay able to run on **Windows PowerShell 5.1** (no PowerShell 7-only syntax).
- `Bug-Report.ps1` writes output as UTF-8 **with BOM**; do not change encodings.
- Logs live under `Logs/<Name>/` and are git-ignored; never commit log output.
- Do not add scripts that make network calls or persist elevated privileges.
  `WinGet-Upgrade.bat` is the sole exception (delegates to `winget`).
- Commit message style: English, imperative, with a `type:` prefix
  (`fix:`, `docs:`, `chore:`, `test:`). Match the existing Conventional
  Commits history.

### Commands

Verification on Windows PowerShell 5.1 (Pester 5.7.1 installed):

```powershell
# Regression tests
powershell -NoProfile -Command "Invoke-Pester -Path ./Tests -Output Detailed"

# Syntax check all PowerShell sources
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('Scripts/Bug-Report.ps1', [ref]$null, [ref]$errors); $errors"

# Trailing-whitespace scan (matches the CI gate)
git show --format= --unified=0 HEAD | Select-String -Pattern '^\+.*[ \t]+$'
```

`.bat` files are not covered by Pester; verify them with a dry review of
quoted paths and `%ERRORLEVEL%` handling.

### Configuration files

- `.gitattributes` enforces `eol=crlf` for `.bat`/`.ps1` and `eol=lf` for `.yml`.
- `.editorconfig` mirrors those line-ending rules plus indentation.
- `.gitlab-ci.yml` mirrors the GitHub quality gates and runs on GitLab CI.
  Pipelines trigger on pushes to `main`; the pipeline badge in `README.md`
  resolves to https://gitlab.com/bayraktarozcan/Maintenance-Scripts/-/pipelines.

---

<a id="tr"></a>

## Türkçe

Bu depoda çalışan AI kodlama ajanları için rehber.

### Proje

Kişisel Windows bakım betikleri koleksiyonu: dört `.bat` başlatıcı artı bir
PowerShell HTML rapor motoru. `Bug-Report.ps1` tek PowerShell mantığıdır;
`.bat` dosyaları sistem araçlarının (`DISM`, `SFC`, `ipconfig`, `winget`)
ince sarmalayıcılarıdır. `.bat` başlatıcıları araçları satır içinde çalıştırır ve
`-ExecutionPolicy Bypass` hiç geçirmez; yalnızca günlük zaman damgaları için
`powershell -NoProfile` çağırır. `Bug-Report.ps1` ayrı çağrılır (örn. zamanlanmış
görev): `-NoProfile -ExecutionPolicy Bypass -File`.

### Temel kurallar

- Betikler **Windows PowerShell 5.1** üzerinde çalışabilir kalmalıdır (PowerShell 7'ye özgü sözdizimi yok).
- `Bug-Report.ps1` çıktıyı UTF-8 **BOM ile** yazar; kodlamaları değiştirmeyin.
- Günlükler `Logs/<Ad>/` altında yaşar ve git-ignored'dır; günlük çıktısını asla commit'lemeyin.
- Ağ çağrısı yapan ya da kalıcı ayrıcalık sürdüren betikler eklemeyin.
  `WinGet-Upgrade.bat` tek istisnadır (`winget`'e iletir).
- Commit mesajı stili: İngilizce, emir kipi, `type:` önekiyle
  (`fix:`, `docs:`, `chore:`, `test:`). Mevcut Conventional Commits
  geçmişiyle uyumlu olsun.

### Komutlar

Windows PowerShell 5.1 üzerinde doğrulama (Pester 5.7.1 kurulu):

```powershell
# Regression testleri
powershell -NoProfile -Command "Invoke-Pester -Path ./Tests -Output Detailed"

# Tüm PowerShell kaynaklarının sözdizimi denetimi
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('Scripts/Bug-Report.ps1', [ref]$null, [ref]$errors); $errors"

# Sondaki boşluk taraması (CI gate ile aynı)
git show --format= --unified=0 HEAD | Select-String -Pattern '^\+.*[ \t]+$'
```

`.bat` dosyaları Pester kapsamında değildir; tırnaklı yolları ve
`%ERRORLEVEL%` kullanımını kuru bir incelemeyle doğrulayın.

### Yapılandırma dosyaları

- `.gitattributes`, `.bat`/`.ps1` için `eol=crlf`, `.yml` için `eol=lf` zorunlu kılar.
- `.editorconfig` bu satır sonu kurallarını ve girintilemeyi yansıtır.
- `.gitlab-ci.yml`, GitHub kalite gate'lerini yansıtır ve GitLab CI'da koşar.
  Pipeline'lar `main`'e yapılan itmelerde tetiklenir; `README.md`'deki pipeline
  rozeti https://gitlab.com/bayraktarozcan/Maintenance-Scripts/-/pipelines
  adresine çözümlenir.
