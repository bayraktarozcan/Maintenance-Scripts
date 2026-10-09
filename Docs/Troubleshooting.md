# Troubleshooting / Sorun Giderme

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

<a id="en"></a>

## English

### A step fails with "Access denied"

`Repair-Windows.bat` and `Reset-Windows-Update.bat` must run as
administrator (right-click → Run as administrator). The log file shows
which numbered step failed; re-run elevated.

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

<a id="tr"></a>

## Türkçe

### Bir adım "Erişim engellendi" ile başarısız oluyor

`Repair-Windows.bat` ve `Reset-Windows-Update.bat` yönetici olarak
çalışmalıdır (sağ tık → Yönetici olarak çalıştır). Hangi numaralı adımın
başarısız olduğu günlükte görünür; yükseltilmiş olarak yeniden çalıştırın.

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
