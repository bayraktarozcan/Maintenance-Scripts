# Release Note Template

Copy the template below and fill in placeholders when creating new releases.
Yeni sürümlerde aşağıdaki şablonu kopyalayıp yer tutucuları doldurun.

---

```markdown
## v{VERSION} — {TITLE}

**{ONE_LINE_SUMMARY}**

### Summary / Özet

{BRIEF_DESCRIPTION}

### Added / Eklenenler

- {SCRIPT_OR_FEATURE} — {DESCRIPTION}

### Changed / Değişenler

- {CHANGE_DESCRIPTION}

### Removed / Kaldırılanlar

- {ITEM} — {REASON}

### Files / Dosyalar

- `Scripts/...` — {NOTE}

### Verification / Doğrulama

- {HOW_IT_WAS_TESTED}
```

---

## Example / Örnek: v0.1.0.0

```markdown
## v0.1.0.0 — Initial collection

**Five maintenance scripts with per-script logging.**

### Summary / Özet

First public release of the personal maintenance collection.

### Added / Eklenenler

- `Repair-Windows.bat`, `Reset-Windows-Update.bat`, `IPConfig-FlushDNS.bat`,
  `WinGet-Upgrade.bat`, `Bug-Report.ps1`

### Verification / Doğrulama

- Dry runs and live runs on Windows 11 25H2; parser-clean PowerShell.
```
