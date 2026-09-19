# AGENTS.md

Guidance for AI coding agents working in this repository.

## Project

Personal Windows maintenance script collection: four `.bat` launchers plus a
PowerShell HTML report engine. `Bug-Report.ps1` is the only PowerShell logic;
the `.bat` files are thin wrappers around system tools (`DISM`, `SFC`,
`ipconfig`, `winget`). The `.bat` launchers run the tools inline and never pass
`-ExecutionPolicy Bypass`; they only invoke `powershell -NoProfile` to build
log timestamps. `Bug-Report.ps1` is called separately (e.g. scheduled task)
with `-NoProfile -ExecutionPolicy Bypass -File`.

## Ground rules

- Scripts must stay able to run on **Windows PowerShell 5.1** (no PowerShell 7-only syntax).
- `Bug-Report.ps1` writes output as UTF-8 **with BOM**; do not change encodings.
- Logs live under `Logs/<Name>/` and are git-ignored; never commit log output.
- Do not add scripts that make network calls or persist elevated privileges.
  `WinGet-Upgrade.bat` is the sole exception (delegates to `winget`).
- Commit message style: English, imperative, with a `type:` prefix
  (`fix:`, `docs:`, `chore:`, `test:`). Match the existing Conventional
  Commits history.

## Commands

Verification on Windows PowerShell 5.1 (Pester 5.7.1 installed):

```powershell
# Regression tests
powershell -NoProfile -Command "Invoke-Pester -Path ./Tests -Output Detailed"

# Syntax check all PowerShell sources
powershell -NoProfile -Command "[void][System.Management.Automation.Language.Parser]::ParseFile('Scripts/Bug-Report.ps1', [ref]$null, [ref]$errors); $errors"

# Trailing-whitespace scan (matches the CI gate)
git show --format= --unified=0 HEAD | Select-String -Pattern '^\+.*[ \t]+$'
```

`.bat` files are not covered by Pester; verify them with a dry review of
quoted paths and `%ERRORLEVEL%` handling.

## Configuration files

- `.gitattributes` enforces `eol=crlf` for `.bat`/`.ps1` and `eol=lf` for `.yml`.
- `.editorconfig` mirrors those line-ending rules plus indentation.
- `.gitlab-ci.yml` mirrors the GitHub quality gates and runs on GitLab CI.
  Pipelines trigger on pushes to `main`; the pipeline badge in `README.md`
  resolves to https://gitlab.com/bayraktarozcan/Maintenance-Scripts/-/pipelines.