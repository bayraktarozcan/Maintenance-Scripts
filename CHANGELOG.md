# Changelog / Değişiklik Günlüğü

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### v0.1.0.0 — 2026-09-16

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

### v0.1.0.0 — 2026-09-16

İlk sürüm: kişisel Windows bakım betikleri koleksiyonu.

**Eklenen:**
- `Repair-Windows.bat` — DISM + SFC + WinSxS bakımı (ResetBase dahil).
- `Reset-Windows-Update.bat` — Windows Update bileşen sıfırlama.
- `IPConfig-FlushDNS.bat` — DNS önbellek temizleme.
- `WinGet-Upgrade.bat` — toplu paket yükseltme.
- `Bug-Report.ps1` — tek dosyalık günlük/günlük-haftalık/aylık HTML rapor motoru (`-Period`).

**Altyapı:**
- Her betik kendi `Logs/<Ad>/` klasörünü açar, `index.txt` koşu dökümü tutar.
- Konsol ve günlük çıktısı birebir aynıdır; günlükler BOM'lu UTF-8 yazılır.
- `Logs/` içerikleri repoya girmez.
