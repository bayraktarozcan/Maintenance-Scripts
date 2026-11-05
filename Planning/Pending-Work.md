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
- [x] Update-Components: `-Check`/argument forwarding added to `Scripts/Update-Components.bat`; static test added for the launcher. Remaining: add to GitHub/GitLab CI quality gate (syntax, tests) as a new script if CI integration rules require explicit listing.
- [ ] Update-Components: consider adding `--report` JSON output for
      programmatic consumption in CI/CD.
- [ ] Update-Components: verify `pip index versions` fallback works with
      current pip version; may need `--use-feature=fast-deps`.
