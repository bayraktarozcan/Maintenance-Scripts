# Security Policy / Güvenlik Politikası

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### Supported versions

Only the latest **release** is supported. When a new release is published, the
previous releases are **deprecated** and no longer supported; each deprecated
release's title carries a `[DEPRECATED]` prefix. Older commits, branches, and
forks are not supported.

### Security posture

- Scripts never upload or transmit data and write **no registry keys**. Only `WinGet-Upgrade.bat` triggers network activity: it delegates package upgrades to `winget`, which queries configured sources and downloads packages. The other scripts make **no network calls** and download **no external files**.
- `Repair-Windows.bat` and `Reset-Windows-Update.bat` **require administrator rights** (they run system commands); elevation is never persisted.
- Logs are written to local disk only and never transmitted.

### Reporting

If you find a security issue, do not open a public issue:

- Report privately via [GitHub Security Advisory](https://github.com/bayraktarozcan/Maintenance-Scripts/security/advisories/new).
- For non-critical concerns you may open an issue with the `security` label.

Target: first response within 48 hours, fix or statement within 14 days.

### Out of scope

- Vulnerabilities in Windows, PowerShell, DISM, SFC, or winget themselves (report to their vendors).
- Attacks requiring physical access.

---

<a id="tr"></a>

## Türkçe

### Desteklenen sürümler

Yalnızca en son **sürüm** desteklenir. Yeni bir sürüm yayımlandığında önceki
sürümler **kullanımdan kaldırılır** ve artık desteklenmez; kullanımdan
kaldırılan her sürümün başlığında `[DEPRECATED]` ön eki bulunur. Eski
commitler, dallar ve çatallar desteklenmez.

### Güvenlik duruşu

- Betikler asla veri yüklemez veya aktarmaz ve kayıt defterine **yazmaz**. Ağ etkinliğini tetikleyen tek betik `WinGet-Upgrade.bat`'tir: paket yükseltmelerini `winget`'e delege eder; winget yapılandırılmış kaynakları sorgular ve paket indirir. Diğer betikler **ağ çağrısı yapmaz** ve harici dosya **indirmez**.
- `Repair-Windows.bat` ve `Reset-Windows-Update.bat` **yönetici hakkı** ister (sistem komutları çalıştırdıkları için); yetki kalıcı hale getirilmez.
- Günlükler yalnızca yerel diske yazılır, dışarı gönderilmez.

### Bildirim

Güvenlik sorunu bulursanız herkese açık issue açmayın:

- [GitHub Security Advisory](https://github.com/bayraktarozcan/Maintenance-Scripts/security/advisories/new) üzerinden gizli bildirin.
- Kritik olmayan konular için `security` etiketli issue açabilirsiniz.

Hedef: 48 saat içinde ilk yanıt, 14 gün içinde düzeltme veya açıklama.

### Kapsam dışı

- Windows, PowerShell, DISM, SFC, winget araçlarının kendi açıkları (üreticilerine bildirin).
- Fiziksel erişim gerektiren saldırılar.
