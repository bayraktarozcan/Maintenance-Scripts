# Contributing / Katkı Rehberi

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

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
- When adding files, check `.gitignore` scope (log contents must stay out).

### Commit message

English, imperative mood, [Conventional Commits](https://www.conventionalcommits.org/) type prefix, short subject + bullet body. Every commit must have both a subject line and bullet details, no empty commits. Types: `feat:` (feature), `fix:` (bug fix), `docs:` (docs only), `style:` (formatting), `refactor:` (no behavior change), `perf:` (performance), `test:` (tests), `build:` (build/deps), `ci:` (CI), `chore:` (maintenance), `revert:` (revert):

```text
feat: add dry-run mode to cleanup script

- Simulate every step with zero system changes
- Mark log name and content as dry-run
```

### Conduct and security

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) applies. Report security findings via [SECURITY.md](SECURITY.md), never via public issues.

---

<a id="tr"></a>

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
- Yeni dosya ekleniyorsa `.gitignore` kapsamı kontrol edilmeli (günlük içerikleri repoya girmemeli).

### Commit mesajı

İngilizce, emir kipi, [Conventional Commits](https://www.conventionalcommits.org/) tür öneki, kısa başlık + madde açıklamalar. Her committe başlık ve madde açıklama zorunludur, boş commit olmaz. Türler: `feat:` (özellik), `fix:` (hata düzeltme), `docs:` (yalnızca belge), `style:` (biçim), `refactor:` (davranışsız değişiklik), `perf:` (performans), `test:` (test), `build:` (derleme/bağımlılık), `ci:` (CI), `chore:` (bakım), `revert:` (geri alma):

```text
feat: add dry-run mode to cleanup script

- Simulate every step with zero system changes
- Mark log name and content as dry-run
```

### Davranış ve güvenlik

[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) geçerlidir. Güvenlik bulguları herkese açık issue ile değil, [SECURITY.md](SECURITY.md) yolundan bildirilir.
