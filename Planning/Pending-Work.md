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
