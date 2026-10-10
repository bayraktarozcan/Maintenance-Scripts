# Pending Work

Tracked follow-ups owned by the human reviewer (not the agent):

- [ ] Review the `Scripts/WinGet-Upgrade.bat` working-copy diff (session
      probe + `--scope` wiring + `WG_DRYRUN`); commit when approved.
- [ ] Run the elevated-session test manually (agent never opens an
      elevated window): expect `Oturum: Yükseltilmiş` and `SCOPE: machine`.
- [ ] After the commit, push `origin main` (dual URL: GitHub + GitLab) and
      confirm the Quality workflow stays green with the new
      `Tests/WinGet-Upgrade.Tests.ps1` suite.
