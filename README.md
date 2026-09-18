# Maintenance Scripts

Personal Windows maintenance scripts — minimal, traceable, Turkish and English.

Kişisel Windows bakım betikleri — sade, izlenebilir, Türkçe ve İngilizce.

[![License](https://img.shields.io/badge/License-MIT-22C55E?style=flat-square)](LICENSE)
[![Validate](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Maintenance-Scripts/validate.yml?branch=main&label=Validate&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Maintenance-Scripts/actions/workflows/validate.yml)
[![Secret Scan](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Maintenance-Scripts/secret-scan.yml?branch=main&label=Secret%20Scan&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Maintenance-Scripts/actions/workflows/secret-scan.yml)
[![Quality](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Maintenance-Scripts/quality.yml?branch=main&label=Quality&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Maintenance-Scripts/actions/workflows/quality.yml)
[![Hygiene](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Maintenance-Scripts/hygiene.yml?branch=main&label=Hygiene&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Maintenance-Scripts/actions/workflows/hygiene.yml)
[![Link Check](https://img.shields.io/github/actions/workflow/status/bayraktarozcan/Maintenance-Scripts/link-check.yml?branch=main&label=Link%20Check&style=flat-square&logo=github)](https://github.com/bayraktarozcan/Maintenance-Scripts/actions/workflows/link-check.yml)
[![GitLab CI](https://img.shields.io/gitlab/pipeline/bayraktarozcan/Maintenance-Scripts/main?branch=main&style=flat-square&logo=gitlab&label=GitLab%20CI)](https://gitlab.com/bayraktarozcan/Maintenance-Scripts/-/pipelines)

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

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

1. Run `Scripts/<name>.bat` as administrator (right-click → Run as administrator).
2. Each script logs under `Logs/<Script-Name>/`; every folder keeps an `index.txt` run ledger.
3. `Bug-Report.ps1` runs on a schedule:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\Bug-Report.ps1" -Period Daily`

### Rules

- Everything outside `Scripts/` is local (see `.gitignore`); scripts create and use their `Logs/` folder at runtime.
- Console and log output are identical.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for contributions, [SUPPORT.md](SUPPORT.md) for help, [PRIVACY.md](PRIVACY.md) for data handling, and [SECURITY.md](SECURITY.md) for security.

---

<a id="tr"></a>

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

1. `Scripts/` klasöründeki betiği yönetici olarak çalıştırın (sağ tık → Yönetici olarak çalıştır).
2. Her betik günlüğünü `Logs/<Betik-Adı>/` altına yazar; her klasörde `index.txt` koşu dökümünü tutar.
3. `Bug-Report.ps1` Zamanlayıcı ile koşar:
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\Bug-Report.ps1" -Period Daily`

### Kurallar

- `Scripts/` dışındaki her şey yereldir (ayrıntı `.gitignore`); betikler `Logs/` klasörünü çalışırken kendileri açar ve kullanır.
- Çıktı hem ekranda hem günlükte birebir aynıdır.
- Katkı için [CONTRIBUTING.md](CONTRIBUTING.md), destek için [SUPPORT.md](SUPPORT.md), gizlilik için [PRIVACY.md](PRIVACY.md) ve güvenlik için [SECURITY.md](SECURITY.md) dosyasına bakın.
