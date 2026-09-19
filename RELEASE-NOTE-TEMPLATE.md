# Release Note Template

Copy the template below and fill in placeholders when creating new releases.
Yeni sürümlerde aşağıdaki şablonu kopyalayıp yer tutucuları doldurun.

> **Language / Dil:** [English](#en) · [Türkçe](#tr)

---

<a id="en"></a>

## English

```markdown
## v{VERSION} - {TITLE}

**{ONE_LINE_SUMMARY}**

### Summary

{BRIEF_DESCRIPTION}

### Added

- {SCRIPT_OR_FEATURE} - {DESCRIPTION}

### Changed

- {CHANGE_DESCRIPTION}

### Removed

- {ITEM} - {REASON}

### Files

- `Scripts/...` - {NOTE}

### Verification

- {HOW_IT_WAS_TESTED}
```

---

<a id="tr"></a>

## Türkçe

```markdown
## v{VERSION} - {TITLE}

**{ONE_LINE_SUMMARY}**

### Özet

{BRIEF_DESCRIPTION}

### Eklenenler

- {SCRIPT_OR_FEATURE} - {DESCRIPTION}

### Değişenler

- {CHANGE_DESCRIPTION}

### Kaldırılanlar

- {ITEM} - {REASON}

### Dosyalar

- `Scripts/...` - {NOTE}

### Doğrulama

- {HOW_IT_WAS_TESTED}
```

---

## Example / Örnek: v0.1.0.0

### English

```markdown
## v0.1.0.0 - Initial Collection

**Five maintenance scripts with per-script logging.**

### Summary

First public release of the personal Windows maintenance collection.

### Added

- `Repair-Windows.bat`, `Reset-Windows-Update.bat`, `IPConfig-FlushDNS.bat`,
  `WinGet-Upgrade.bat`, `Bug-Report.ps1`

### Verification

- Dry runs and live runs on Windows 11 25H2; parser-clean PowerShell.
```

### Türkçe

```markdown
## v0.1.0.0 - İlk Koleksiyon

**Betik başına günlük tutan beş bakım betiği.**

### Özet

Kişisel Windows bakım koleksiyonunun ilk herkese açık sürümü.

### Eklenenler

- `Repair-Windows.bat`, `Reset-Windows-Update.bat`, `IPConfig-FlushDNS.bat`,
  `WinGet-Upgrade.bat`, `Bug-Report.ps1`

### Doğrulama

- Windows 11 25H2 üzerinde kuru ve canlı koşular; ayrıştırıcı-temiz PowerShell.
```
