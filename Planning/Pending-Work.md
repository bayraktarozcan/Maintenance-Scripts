# Pending Work
 
Tracked follow-ups owned by the human reviewer (not the agent):
 
- [x] WinGet scope feature: ABANDONED. The session-probe/`--scope`
      change was reverted (false positives under Admin Protection);
      related docs were mirrored back. No review or elevated test needed.
- [x] Push `origin main` (dual URL: GitHub + GitLab) after the
      launcher/gate batch; GitHub workflows stayed green.
- [x] GitLab pipeline quota: no action. Pipelines #34–#52 were
      `ci_quota_exceeded`; GitHub is the enforcing host, so GitLab
      settings, `.gitlab-ci.yml`, and the README badge stay unchanged.
- [x] Update-Components: `-Check`/argument forwarding added to `Scripts/Update-Components.bat`; static tests added (`Tests/Update-Components.Tests.ps1`, `Tests/Update-ComponentsBat.Tests.ps1`); hybrid winget detection (Microsoft.WinGet.Client when available, `--upgrade-available`, fixed-width table parsing, honest `Denetlenemedi`) and Python winget ID resolution implemented. CI integration requires no explicit file listing: `quality.yml`/GitLab `quality` run Pester over `./Tests`, `validate.yml`/GitLab `validate` parse every `*.ps1` recursively, and `Tools/Invoke-Gate.ps1` runs the same checks — `4598c0c`.
- [x] Update-Components: `--report` JSON output added (`-ReportPath`, schema v1, `check`/`execute`, `plan`/`result`/`success`/`exitCode`); covered by static tests and docs.
- [x] Update-Components: `pip index versions` fallback verified on pip 26.3 (`Available versions: <latest>, ...` parsed by `Get-LatestFromIndexVersions`); `--use-feature=fast-deps` is not supported on pip 26.x and is not used. CI consumption remains network-dependent by design for real runs; use `-Check -ReportPath` for side-effect-free checks.
