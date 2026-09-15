# Automation Scripts

Personal Windows maintenance scripts — minimal, traceable, Turkish and English.

Kişisel Windows bakım betikleri — sade, izlenebilir, Türkçe ve İngilizce.

[![License](https://img.shields.io/badge/License-MIT-22C55E?style=flat-square)](LICENSE)
[![Validate](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Automation-Scripts/validate.yml?branch=main&label=Validate&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Automation-Scripts/actions/workflows/validate.yml)
[![Secret Scan](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Automation-Scripts/secret-scan.yml?branch=main&label=Secret%20Scan&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Automation-Scripts/actions/workflows/secret-scan.yml)
[![Quality](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Automation-Scripts/quality.yml?branch=main&label=Quality&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Automation-Scripts/actions/workflows/quality.yml)

> **Language / Dil:** [English](#english) · [Türkçe](#türkçe)

---

## English

### What is this?

Each script does one job: it runs commands in order and writes output both to the console and to its own log folder. No menus, no options, no surprises.

### Scripts

| Script | Does |
|---|---|
| `Repair-Windows.bat` | DISM + SFC + WinSxS maintenance (includes ResetBase) |
| `Reset-Windows-Update.bat` | Reset Windows Update components |
| `IPConfig-FlushDNS.bat` | Flush DNS cache |
| `WinGet-Upgrade.bat` | Upgrade all packages |
| `Bug-Report.ps1` | Event log HTML report (`-Period Daily, Weekly, Monthly`) |

### Usage

1. Run from a shortcut in `Shortcuts/` (requires administrator rights).
2. Each script logs under `Logs/<Script-Name>/`; every folder keeps an `index.txt` run ledger.
3. `Bug-Report.ps1` runs on a schedule:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\Bug-Report.ps1" -Period Daily`

### Rules

- Everything outside `Scripts/` is local (shortcuts, logs, IDE settings).
- Console and log output are identical.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for contributions and [SECURITY.md](SECURITY.md) for security.

---

## Türkçe

### Nedir?

Her betik tek iş yapar: komutları sırayla çalıştırır, çıktıyı hem ekrana hem de kendi günlük klasörüne yazar. Menü yok, seçenek yok, sürpriz yok.

### Betikler

| Betik | İş |
|---|---|
| `Repair-Windows.bat` | DISM + SFC + WinSxS bakımı (ResetBase dahil) |
| `Reset-Windows-Update.bat` | Windows Update bileşenlerini sıfırlama |
| `IPConfig-FlushDNS.bat` | DNS önbelleğini temizleme |
| `WinGet-Upgrade.bat` | Tüm paketleri yükseltme |
| `Bug-Report.ps1` | Olay günlüğü HTML raporu (`-Period Daily, Weekly, Monthly`) |

### Kullanım

1. `Shortcuts/` klasöründeki kısayoldan çalıştırın (yönetici hakkı ister).
2. Her betik günlüğünü `Logs/<Betik-Adı>/` altına yazar; her klasörde `index.txt` koşu dökümünü tutar.
3. `Bug-Report.ps1` Zamanlayıcı ile koşar:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\Bug-Report.ps1" -Period Daily`

### Kurallar

- `Scripts/` dışındaki her şey yereldir (kısayol, günlük, IDE ayarları).
- Çıktı hem ekranda hem günlükte birebir aynıdır.
- Katkı için [CONTRIBUTING.md](CONTRIBUTING.md), güvenlik için [SECURITY.md](SECURITY.md) dosyasına bakın.
