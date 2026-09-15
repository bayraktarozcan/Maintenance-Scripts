# Contributing / Katkı Rehberi

> **Language / Dil:** [English](#english) · [Türkçe](#türkçe)

---

## English

### Workflow

1. Open a topic branch from `main` (`feature/...`, `fix/...`).
2. Make the change, run the [checklist](#checklist) below.
3. Open a pull request describing what changed and why.

### Checklist

- For `.ps1`: must pass parser syntax check.
- For `.bat`: must pass an end-to-end dry run on a harmless copy.
- Run `Invoke-Pester ./Tests` — all tests must pass.
- Keep the log naming rule: `<Name>_<yyyyMMdd_HHmmss>.<ext>`.
- When adding files, check `.gitignore` scope (logs/shortcuts must stay out).

### Commit message

English, imperative mood, short subject + bullet body:

```text
Add dry-run mode to cleanup script

- Simulate every step with zero system changes
- Mark log name and content as dry-run
```

### Conduct and security

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies. Report security findings via [SECURITY.md](SECURITY.md), never via public issues.

---

## Türkçe

### İş akışı

1. `main` dalından konu dalı açın (`ozellik/...`, `duzeltme/...`).
2. Değişikliği yapın, [aşağıdaki](#test-listesi) testleri koşun.
3. Pull request açın; neyin neden değiştiğini yazın.

### Test listesi

- `.ps1` için: sözdizimi ayrıştırması hatasız olmalı.
- `.bat` için: zararsız bir kopyada uçtan uca kuru koşu yapılmalı.
- `Invoke-Pester ./Tests` koşulmalı — tüm testler geçmeli.
- Log adlandırma kuralı korunmalı: `<Ad>_<yyyyMMdd_HHmmss>.<uzantı>`.
- Yeni dosya ekleniyorsa `.gitignore` kapsamı kontrol edilmeli (günlük/kısayol repoya girmemeli).

### Commit mesajı

İngilizce, emir kipi, kısa başlık + madde açıklamalar:

```text
Add dry-run mode to cleanup script

- Simulate every step with zero system changes
- Mark log name and content as dry-run
```

### Davranış ve güvenlik

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) geçerlidir. Güvenlik bulguları herkese açık issue ile değil, [SECURITY.md](SECURITY.md) yolundan bildirilir.
