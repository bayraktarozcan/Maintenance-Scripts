# Changelog / Değişiklik Günlüğü

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### Unreleased

**Changed:**
- `.bat` launchers resolve one PowerShell engine per run (`pwsh` app alias, `pwsh` from PATH, then Windows PowerShell 5.1) and reuse it for timestamps, BOM checks, workload, and drain calls.
- `Repair-Windows.bat` records per-stage start/end timestamps, exit codes and elapsed milliseconds, then prints a nine-line summary, total time and an overall status; missing evidence reports `INDETERMINATE` instead of success.
- `Clear-DnsClientCache.bat` clears an inherited `NOPAUSE` variable before parsing `/nopause`.

**Fixed:**
- Launcher timestamps no longer break when the PowerShell path contains `(` or `&`.
- The local gate fails when `actionlint` or `lychee` is missing instead of reporting a skipped check and exiting 0; its header now states that LinkCheck fetches URLs.
- `Invoke-Gate.Tests.ps1` maps every gate check to its workflow step and pins the workflow file set.

### v0.1.0.0 — 2026-09-16

First release: personal Windows maintenance script collection.

**Added:**
- `Repair-Windows.bat` — DISM + SFC + WinSxS maintenance (includes ResetBase).
- `Reset-Windows-Update.bat` — reset Windows Update components.
- `Clear-DnsClientCache.bat` — flush DNS cache.
- `WinGet-Upgrade.bat` — upgrade all packages.
- `Bug-Report.ps1` — single-file daily/weekly/monthly HTML report engine (`-Period`).

**Infrastructure:**
- Each script creates its own `Logs/<Name>/` folder and keeps an `index.txt` run ledger.
- Console and log output are identical; logs are written as UTF-8 with BOM.
- `Logs/` contents stay out of version control.

---

<a id="tr"></a>

## Türkçe

### Yayınlanmamış

**Değişen:**
- `.bat` başlatıcıları her koşuda tek bir PowerShell motoru çözer (`pwsh` uygulama diğer adı, PATH'teki `pwsh`, sonra Windows PowerShell 5.1) ve zaman damgası, BOM denetimi, iş yükü ve boşaltma çağrılarında onu yeniden kullanır.
- `Repair-Windows.bat` her aşama için başlangıç/bitiş zaman damgası, çıkış kodu ve geçen milisaniyeyi kaydeder; ardından dokuz satırlık özet, toplam süre ve genel durum yazar; eksik kanıt başarı yerine `INDETERMINATE` bildirir.
- `Clear-DnsClientCache.bat`, `/nopause` bağımsız değişkenini ayrıştırmadan önce devralınan `NOPAUSE` değişkenini temizler.

**Düzeltilen:**
- PowerShell yolu `(` veya `&` içerdiğinde başlatıcı zaman damgaları artık bozulmaz.
- Yerel geçit, `actionlint` veya `lychee` eksikken atlanan denetim bildirip 0 ile çıkmak yerine başarısız olur; başlığı artık LinkCheck'in URL'leri getirdiğini belirtir.
- `Invoke-Gate.Tests.ps1`, her geçit denetimini iş akışı adımına eşler ve iş akışı dosya kümesini sabitler.

### v0.1.0.0 — 2026-09-16

İlk sürüm: kişisel Windows bakım betikleri koleksiyonu.

**Eklenen:**
- `Repair-Windows.bat` — DISM + SFC + WinSxS bakımı (ResetBase dahil).
- `Reset-Windows-Update.bat` — Windows Update bileşenlerini sıfırlama.
- `Clear-DnsClientCache.bat` — DNS önbelleğini temizleme.
- `WinGet-Upgrade.bat` — toplu paket yükseltme.
- `Bug-Report.ps1` — tek dosyalık günlük/haftalık/aylık HTML rapor motoru (`-Period`).

**Altyapı:**
- Her betik kendi `Logs/<Ad>/` klasörünü açar, `index.txt` koşu dökümü tutar.
- Konsol ve günlük çıktısı birebir aynıdır; günlükler BOM'lu UTF-8 yazılır.
- `Logs/` içerikleri repoya girmez.
