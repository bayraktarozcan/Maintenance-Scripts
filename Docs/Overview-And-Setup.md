# Overview and Setup / Genel Bakış ve Kurulum

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

### What this project is

A personal Windows maintenance collection: four `.bat` launchers that run
system tools inline, plus one PowerShell HTML report engine
(`Scripts/Bug-Report.ps1`). See [README.md](../README.md) for the script
table and [Architecture](Architecture.md) for how they work.

### Requirements

- Windows with `cmd.exe`, PowerShell 5.1+, and (for `WinGet-Upgrade.bat`)
  `winget`. The launchers prefer `pwsh` when it is on `PATH` and fall back
  to Windows PowerShell 5.1; PowerShell 7.6.7 is the recommended `pwsh`
  line. The full host manifest and setup live in the project layer
  (`Dependencies`):
  `powershell -NoProfile -File Tools/Install-Dependencies.ps1`.
- Administrator rights for `Repair-Windows.bat` and
  `Reset-Windows-Update.bat` only; the other scripts run as a normal user.
- Elevation posture: no launcher self-elevates; run everything standard
  except the two admin scripts above (see [SECURITY.md](../SECURITY.md)).
- `Bug-Report.ps1` reads the System and Application event logs, so the
  scheduling account needs permission to read them.

### Setup

No installation step exists. Clone the repository and run a launcher from
`Scripts/`, or schedule `Bug-Report.ps1`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\Bug-Report.ps1" -Period Daily
```

`-Period` accepts `Daily`, `Weekly`, or `Monthly`. Each run creates its log
folder on first use; runtime output lives under `Logs/<Name>/` and is never
committed (see [`.gitignore`](../.gitignore)). For local development hooks,
see [CONTRIBUTING.md](../CONTRIBUTING.md).

<a id="tr"></a>

## Türkçe

### Bu proje nedir

Kişisel bir Windows bakım koleksiyonu: sistem araçlarını satır içi çalıştıran
dört `.bat` başlatıcı ile bir PowerShell HTML rapor motoru
(`Scripts/Bug-Report.ps1`). Betik tablosu için [README.md](../README.md),
çalışma biçimi için [Mimari](Architecture.md) dosyasına bakın.

### Gereksinimler

- `cmd.exe`, PowerShell 5.1+ ve (`WinGet-Upgrade.bat` için) `winget`
  bulunan Windows. Başlatıcılar `PATH` üzerinde `pwsh` varsa onu yeğler,
  yoksa Windows PowerShell 5.1'e düşer; önerilen `pwsh` sürümü 7.6.7'dir.
  Tam konak bildirimi ve kurulum proje katmanındadır (`Dependencies`):
  `powershell -NoProfile -File Tools/Install-Dependencies.ps1`.
- Yalnızca `Repair-Windows.bat` ve `Reset-Windows-Update.bat` yönetici
  hakkı ister; diğer betikler normal kullanıcı olarak koşar.
- Yükseltme duruşu: hiçbir başlatıcı kendini yükseltmez; yukarıdaki iki
  yönetici betiği dışında her şeyi standart çalıştırın (bkz.
  [SECURITY.md](../SECURITY.md)).
- `Bug-Report.ps1`, System ve Application olay günlüklerini okur; bu yüzden
  zamanlayan hesabın bunları okuma izni olmalıdır.

### Kurulum

Kurulum adımı yoktur. Depoyu klonlayıp `Scripts/` içinden bir başlatıcı
çalıştırın ya da `Bug-Report.ps1` dosyasını zamanlayın:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "Scripts\Bug-Report.ps1" -Period Daily
```

`-Period` değeri `Daily`, `Weekly` veya `Monthly` olur. Her betik günlük
klasörünü ilk kullanımda kendisi açar; çalışma zamanı çıktısı
`Logs/<Ad>/` altında yaşar ve asla commitlenmez (bkz.
[`.gitignore`](../.gitignore)). Yerel geliştirme kancaları için
[CONTRIBUTING.md](../CONTRIBUTING.md) dosyasına bakın.
