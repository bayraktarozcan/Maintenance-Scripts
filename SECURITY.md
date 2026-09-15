# Security Policy / Güvenlik Politikası

> **Language / Dil:** [English](#english) · [Türkçe](#türkçe)

---

## English

### Supported versions

Only the latest commit on the `main` branch is supported. Older commits and forks are not supported.

### Security posture

- Scripts make **no network calls**, download **no external files**, and write **no registry keys**.
- `Repair-Windows.bat` and `Reset-Windows-Update.bat` **require administrator rights** (they run system commands); elevation is never persisted.
- Logs are written to local disk only and never transmitted.

### Reporting

If you find a security issue, do not open a public issue:

- Report privately via [GitHub Security Advisory](https://github.com/bayraktarozcan/Automation-Scripts/security/advisories/new).
- For non-critical concerns you may open an issue with the `security` label.

Target: first response within 48 hours, fix or statement within 14 days.

### Out of scope

- Vulnerabilities in Windows, PowerShell, DISM, SFC, or winget themselves (report to their vendors).
- Attacks requiring physical access.

---

## Türkçe

### Desteklenen sürümler

Yalnızca `main` dalındaki en güncel commit desteklenir. Eski commitler ve çatallar desteklenmez.

### Güvenlik duruşu

- Betikler **ağ çağrısı yapmaz**, harici dosya **indirmez**, kayıt defterine **yazmaz**.
- `Repair-Windows.bat` ve `Reset-Windows-Update.bat` **yönetici hakkı** ister (sistem komutları çalıştırdıkları için); yetki kalıcı hale getirilmez.
- Günlükler yalnızca yerel diske yazılır, dışarı gönderilmez.

### Bildirim

Güvenlik sorunu bulursanız herkese açık issue açmayın:

- [GitHub Security Advisory](https://github.com/bayraktarozcan/Automation-Scripts/security/advisories/new) üzerinden gizli bildirin.
- Kritik olmayan konular için `security` etiketli issue açabilirsiniz.

Hedef: 48 saat içinde ilk yanıt, 14 gün içinde düzeltme veya açıklama.

### Kapsam dışı

- Windows, PowerShell, DISM, SFC, winget araçlarının kendi açıkları (üreticilerine bildirin).
- Fiziksel erişim gerektiren saldırılar.
