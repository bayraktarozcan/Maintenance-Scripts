# Support / Destek

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### Getting help

This is a personal, hobby-maintained collection of Windows maintenance
scripts. Support is best-effort, provided by the author of the repository.

1. Read the [README.md](README.md) — it answers most questions about what each
   script does, how to run it, and how logs work.
2. Search the [issues](https://github.com/bayraktarozcan/Maintenance-Scripts/issues)
   to see whether your question was already asked and answered.
3. Open a new issue with the `question` label if you still need help.

### Before you ask

- Run each script **as administrator** (right-click -> Run as administrator); required for `Repair-Windows.bat` and `Reset-Windows-Update.bat`.
- Check the log folder `Logs/<Script-Name>/` for your run; it shows exactly
  what the script did and failed on.
- Confirm which script you ran and the exact error text you saw.

### What is supported

- Usage questions about the scripts in this repository.
- Bug reports with reproduction steps.

### What is not supported

- General Windows, PowerShell, DISM, SFC, or winget troubleshooting unrelated
  to these scripts. Report issues in those tools to their vendors.
- Requests for new features are welcome as `enhancement` issues but are
  triaged by availability and interest.
- Unrelated or advertisement issues are removed.

### Response

This project has no SLA. Expect an answer when the author has time. If you
need reliable, fast support, treat this collection as reference code rather
than a guarantee.

---

<a id="tr"></a>

## Türkçe

### Yardım almak

Bu, hobi amaçlı, tek kişi tarafından bakılan bir Windows bakım betikleri
koleksiyonudur. Destek; depo sahibi tarafından sağlanan, elinden gelen ölçüde
bir destektir.

1. [README.md](README.md) dosyasını okuyun — betiklerin ne işe yaradığı, nasıl
   çalıştırılacağı ve günlüklerin nasıl işlediği hakkındaki soruların çoğunu
   yanıtlar.
2. Sorunuzun daha önce sorulup yanıtlanmadığını görmek için
   [issues](https://github.com/bayraktarozcan/Maintenance-Scripts/issues)
   bölümünde arama yapın.
3. Hâlâ yardım gerekiyorsa `question` etiketiyle yeni bir issue açın.

### Sormadan önce

- Betikleri **yönetici olarak** çalıştırın (sağ tık -> Yönetici olarak çalıştır); bunu yalnızca `Repair-Windows.bat` ve `Reset-Windows-Update.bat` gerektirir.
- Koşunuzun günlüğüne `Logs/<Betik-Adı>/` klasöründen bakın; betiğin ne yaptığını
  ve nerede hata verdiğini aynen gösterir.
- Hangi betiği çalıştırdığınızı ve gördüğünüz hata metnini olduğu gibi belirtin.

### Desteklenenler

- Bu depodaki betiklerin kullanımıyla ilgili sorular.
- Üretilebilir adım adım açıklaması olan hata bildirimleri.

### Desteklenmeyenler

- Bu betiklerle ilgisi olmayan genel Windows, PowerShell, DISM, SFC veya winget
  sorun giderme. Bu araçlardaki sorunları üreticilerine bildirin.
- `enhancement` etiketli özellik istekleri memnuniyetle karşılanır ancak
  zaman ve ilgiye göre değerlendirilir.
- Konu dışı veya reklam amaçlı issue'lar kaldırılır.

### Yanıt süresi

Bu projenin bir SLA'sı yoktur. Depo sahibinin vakti olduğunda yanıt bekleyin.
Güvenilir ve hızlı desteğe ihtiyacınız varsa, bu koleksiyonu bir garanti değil,
referans kod olarak değerlendirin.