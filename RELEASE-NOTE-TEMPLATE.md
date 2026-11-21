# Release Note Template / Yayın Notu Şablonu

Copy the template below when creating or updating a release. Tüm release'lar
`CHANGELOG.md` kaynaktan üretilir; arayüz metni kaynak değildir.

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

### Title rules

- One version number only, in the form `<tag> — Title Case Description` (em dash, spaces on both sides).
- Every release except the current one starts with `[DEPRECATED] ` — the prefix goes at the **front**, never at the end.
- Title Case with conjunctions lowercase; abbreviations fully uppercase (`API`, `CI`, `ADMX`); mixed-case names such as `IoC`, `PowerShell`, `GitHub` and `Node.js` are preserved.
- No bare issue numbers such as `#5` (the host turns them into links), no emoji, no embedded CHANGELOG table of contents.

### Body rules

- English block first, Turkish block second, at equal scope.
- Section order: `## vX — ...`, `### Summary`, `### Added`, `### Changed`, `### Removed`, `### Fixed`, `### Files`, `### Documentation`.
- An empty category keeps its heading with `- None in this release.`
- Never include lines belonging to another version.

### Template

```markdown
## vX.Y.Z.W — Title Case Description

### Summary

{BRIEF_DESCRIPTION}

### Added

- {FEATURE} - {DESCRIPTION}

### Changed

- {CHANGE_DESCRIPTION}

### Removed

- {ITEM} - {REASON}

### Fixed

- {FIX_DESCRIPTION}

### Files

- `Scripts/...` - {NOTE}

### Documentation

- `Docs/...` - {NOTE}

---

## vX.Y.Z.W — Türkçe Başlık

### Özet

{KISA_AÇIKLAMA}

### Eklenenler

- {ÖZELLİK} - {AÇIKLAMA}

### Değiştirilenler

- {DEĞİŞİKLİK}

### Kaldırılanlar

- {ÖĞE} - {GEREKÇE}

### Düzeltilenler

- {DÜZELTME}

### Dosyalar

- `Scripts/...` - {NOT}

### Belgelendirme

- `Docs/...` - {NOT}
```

### Publication procedure

There is no dedicated release script; the two CLI commands below are the procedure.
`--name` / `--title`, `--notes-file`, `--ref` and `--tag` are the parameters that
must match on both hosts.

```powershell
# GitHub: edit an existing release
gh release edit vX.Y.Z.W --title "[DEPRECATED] vX.Y.Z.W — Title" --notes-file Logs/releases/vX.Y.Z.W.md

# GitLab: create or update (--ref accepts the tag name; an existing release is updated)
glab release create vX.Y.Z.W --name "[DEPRECATED] vX.Y.Z.W — Title" --notes-file Logs/releases/vX.Y.Z.W.md --ref vX.Y.Z.W

# Verify parity over the APIs, not the UI
gh api --paginate "repos/bayraktarozcan/Maintenance-Scripts/releases?per_page=100"
glab api --paginate "projects/bayraktarozcan%2FMaintenance-Scripts/releases?per_page=100"
```

After publishing, prefix the previous release title with `[DEPRECATED] ` on both
hosts and keep the full history in `CHANGELOG.md`.

---

<a id="tr"></a>

## Türkçe

### Başlık kuralları

- Yalnızca bir sürüm numarası: `<tag> — Başlık Büyüklüğünde Açıklama` (en tire, iki yanında boşluk).
- Güncel olan dışındaki tüm release'lar `[DEPRECATED] ` ile **başlar**; önek sona asla konmaz.
- Başlık büyüklüğü, bağlaçlar küçük kalır; kısaltmalar tamamen büyük yazılır (`API`, `CI`, `ADMX`); `IoC`, `PowerShell`, `GitHub`, `Node.js` gibi karışık yazımlar korunur.
- `#5` gibi çıplak numaralar (host bağlantıya çevirir), emoji ve gömülü CHANGELOG içindekileri olmaz.

### Gövde kuralları

- Önce İngilizce, sonra Türkçe blok; kapsam eşit olmalı.
- Bölüm sırası: `## vX — ...`, `### Summary`, `### Added`, `### Changed`, `### Removed`, `### Fixed`, `### Files`, `### Documentation` (TR: `Özet`, `Eklenenler`, `Değiştirilenler`, `Kaldırılanlar`, `Düzeltilenler`, `Dosyalar`, `Belgelendirme`).
- Boş kategori başlığı korunur ve `- Bu sürümde yok.` yazılır.
- Başka bir sürüme ait satır asla eklenmez.

### Yordam

Ayrı bir release betiği yoktur; aşağıdaki iki komut yordamdır.
`--name` / `--title`, `--notes-file`, `--ref` ve `--tag` parametreleri iki hostta da aynı olmalıdır.

```powershell
# GitHub: var olan release'i düzenle
gh release edit vX.Y.Z.W --title "[DEPRECATED] vX.Y.Z.W — Başlık" --notes-file Logs/releases/vX.Y.Z.W.md

# GitLab: oluştur veya güncelle (--ref etiket adını kabul eder; var olan release güncellenir)
glab release create vX.Y.Z.W --name "[DEPRECATED] vX.Y.Z.W — Başlık" --notes-file Logs/releases/vX.Y.Z.W.md --ref vX.Y.Z.W

# Pariteyi arayüz değil API üzerinden doğrula
gh api --paginate "repos/bayraktarozcan/Maintenance-Scripts/releases?per_page=100"
glab api --paginate "projects/bayraktarozcan%2FMaintenance-Scripts/releases?per_page=100"
```

Yayından sonra önceki release başlığı iki hostta da `[DEPRECATED] ` ile öneklenir;
tam geçmiş `CHANGELOG.md` içinde tutulur.
