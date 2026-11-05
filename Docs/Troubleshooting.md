# Troubleshooting / Sorun Giderme

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

### A step fails with "Access denied"

`Repair-Windows.bat` and `Reset-Windows-Update.bat` must run as
administrator (right-click → Run as administrator). The log file shows
which numbered step failed; re-run elevated.

Do not elevate `WinGet-Upgrade.bat` or `Clear-DnsClientCache.bat` to work
around failures; they are designed to run standard. If a package needs
elevation, the tool or installer raises it externally.

### `Bug-Report.ps1` exits immediately or shows no events

- Run it from an account that can read the System and Application event
  logs; otherwise `Get-WinEvent` returns nothing.
- An empty result is normal on a quiet machine: the report still renders
  with zero events. `NoMatchingEventsFound` is handled, not an error.
- Do not pass `-ExecutionPolicy Bypass` from the `.bat` launchers; call
  the script directly as shown in
  [Overview and Setup](Overview-And-Setup.md).

### Logs go to `%TEMP%` instead of `Logs/`

The launcher falls back to `%TEMP%\<Name>` when it cannot create
`Logs/<Name>/` (read-only checkout, missing rights). Check the
`Index:` line at the top of the console output for the actual folder.

### Output looks garbled

Logs are UTF-8 with BOM. Open them in an editor that honors the BOM
(VS Code, Notepad). The console side uses `chcp 65001`; on very old
consoles, redirect to the log file and read it there.

### `winget` not found
 
`WinGet-Upgrade.bat` needs the App Installer (`winget`) from the
Microsoft Store. Install it, then re-run; the log captures the exact
`winget` error text.

### `Update-Components.ps1` reports "Python launcher (py) not found" / "npm not found" / "winget not found"

- The script checks for `py`, `npm`, and `winget` via `Get-Command`. If one is missing, that component is skipped and marked `Atlandı` (Skipped) in the plan/result tables.
- Install the missing tool: Python from winget (`Python.Python.3.15`), Node.js from winget (`OpenJS.NodeJS.LTS`), or winget itself from the Microsoft Store.
- The script exits 0 only if all requested components succeed; missing tools mark the overall run as failed unless `-Check` is used.

### `pip list --outdated --format=json` fails or returns nothing

- Older pip versions (< 21.2) do not support `--format=json`. The script falls back to text parsing automatically.
- If the fallback also returns nothing, all pip packages are up to date.

### `npm outdated -g` shows packages but `npm update -g` does not update them

- Global npm packages follow caret semver ranges. `npm update -g` only updates within the specified range. To force latest, run `npm install -g <pkg>@latest` manually.
- The script uses `npm update -g` per npm best practice (see [npm update docs](https://docs.npmjs.com/cli/v10/commands/npm-update#updating-globally-installed-packages)).

<a id="tr"></a>

## Türkçe

### Bir adım "Erişim engellendi" ile başarısız oluyor

`Repair-Windows.bat` ve `Reset-Windows-Update.bat` yönetici olarak
çalışmalıdır (sağ tık → Yönetici olarak çalıştır). Hangi numaralı adımın
başarısız olduğu günlükte görünür; yükseltilmiş olarak yeniden çalıştırın.

Arızaları aşmak için `WinGet-Upgrade.bat` veya `Clear-DnsClientCache.bat`
dosyasını yükseltmeyin; standart koşmak üzere tasarlandılar. Bir paket
yükseltme isterse araç ya da yükleyici haricen yükseltir.

### `Bug-Report.ps1` hemen çıkıyor ya da olay göstermiyor

- System ve Application olay günlüklerini okuyabilen bir hesapla
  çalıştırın; yoksa `Get-WinEvent` boş döner.
- Sakin bir makinede boş sonuç normaldir: rapor sıfır olayla yine de
  çizilir. `NoMatchingEventsFound` durumu ele alınır, hata değildir.
- `.bat` başlatıcılardan `-ExecutionPolicy Bypass` geçirmeyin; betiği
  [Genel Bakış ve Kurulum](Overview-And-Setup.md) bölümündeki gibi
  doğrudan çağırın.

### Günlükler `Logs/` yerine `%TEMP%` altına gidiyor

`Logs/<Ad>/` açılamadığında (salt okunur ödeme, yetersiz hak)
başlatıcı `%TEMP%\<Ad>` yedeğine düşer. Gerçek klasör için ekran
çıktısının başındaki `Index:` satırına bakın.

### Çıktı bozuk görünüyor

Günlükler BOM'lu UTF-8'dir. BOM'a saygı duyan bir düzenleyicide açın
(VS Code, Not Defteri). Ekran tarafı `chcp 65001` kullanır; çok eski
konsollarda çıktıyı günlük dosyasına yönlendirip oradan okuyun.

### `winget` bulunamıyor
 
`WinGet-Upgrade.bat`, Microsoft Store'dan App Installer (`winget`)
ister. Kurup yeniden çalıştırın; tam `winget` hata metni günlükte
yakalanır.

### `Update-Components.ps1` "Python launcher (py) not found" / "npm not found" / "winget not found" bildiriyor

- Betik `py`, `npm` ve `winget` komutlarını `Get-Command` ile kontrol eder. Biri yoksa ilgili bileşen atlanır ve plan/sonuç tablolarında `Atlandı` olarak işaretlenir.
- Eksik aracı kurun: Python winget'ten (`Python.Python.3.15`), Node.js winget'ten (`OpenJS.NodeJS.LTS`), veya winget'i Microsoft Store'dan.
- Betik, tüm istenen bileşenler başarılı olduğunda 0 ile çıkar; eksik araçlar `-Check` kullanılmadıkça genel çalışmayı başarısız sayar.

### `pip list --outdated --format=json` başarısız oluyor ya da boş dönüyor

- Eski pip sürümleri (< 21.2) `--format=json` desteklemez. Betik otomatik olarak metin ayrıştırmaya (fallback) düşer.
- Fallback da boş dönüyorsa tüm pip paketleri zaten günceldir.

### `npm outdated -g` paketleri gösteriyor ama `npm update -g` güncellemiyor

- Global npm paketleri caret semver aralıklarını takip eder. `npm update -g` sadece belirtilen aralık içine günceller. En son sürüme zorlamak için `npm install -g <pkg>@latest` el ile çalıştırın.
- Betik npm en iyi uygulaması olarak `npm update -g` kullanır (bkz. [npm update belgeleri](https://docs.npmjs.com/cli/v10/commands/npm-update#updating-globally-installed-packages)).
