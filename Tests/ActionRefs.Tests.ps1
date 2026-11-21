# Invariant: every third-party action resolves to a ref that exists upstream.
# The map below was verified against the upstream repositories on 2026-11-21:
# checkout/setup-python/actionlint use main, lychee-action uses master.
# A rule that can rot silently needs its own named test, so this check is
# deterministic and offline; refreshing the map is a code change.
# What it cannot see: a future upstream default-branch rename not yet mapped.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:WorkflowDir = Join-Path $script:RepoRoot '.github/workflows'
    $script:DefaultBranch = [ordered]@{
        'actions/checkout'          = 'main'
        'actions/setup-python'      = 'main'
        'rhysd/actionlint'          = 'main'
        'lycheeverse/lychee-action' = 'master'
    }

    function Get-ActionReferences {
        param([string]$WorkflowDir)
        $references = @()
        foreach ($file in (Get-ChildItem -LiteralPath $WorkflowDir -Filter '*.yml' -File -ErrorAction SilentlyContinue)) {
            $text = [IO.File]::ReadAllText($file.FullName)
            foreach ($match in [regex]::Matches($text, '(?m)^\s*(?:-\s*)?uses:\s*([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)@([^\s#]+)')) {
                $references += [pscustomobject]@{
                    File = $file.Name
                    Repo = $match.Groups[1].Value
                    Ref  = $match.Groups[2].Value
                }
            }
        }
        return $references
    }

    function Test-ActionRefInvariants {
        param([string]$WorkflowDir, [string]$Root)
        $problems = @()
        $references = @(Get-ActionReferences $WorkflowDir)
        if ($references.Count -eq 0) { $problems += 'no action references found' }
        $shas = @($references | Where-Object { $_.Ref -cmatch '^[0-9a-f]{40}$' })
        if ($shas.Count -gt 0) {
            $problems += ('full-commit SHA pins: ' + (($shas | ForEach-Object { "$($_.File): $($_.Repo)@$($_.Ref)" }) -join ', '))
        }
        $unknown = @($references | Where-Object { -not $script:DefaultBranch.Contains($_.Repo) })
        if ($unknown.Count -gt 0) {
            $problems += ('actions outside the verified map: ' + (($unknown | ForEach-Object { "$($_.File): $($_.Repo)" }) -join ', '))
        }
        $wrong = @($references | Where-Object {
            $script:DefaultBranch.Contains($_.Repo) -and $_.Ref -cne $script:DefaultBranch[$_.Repo]
        })
        if ($wrong.Count -gt 0) {
            $problems += ('refs that are not the upstream default branch: ' + (($wrong | ForEach-Object { "$($_.File): $($_.Repo)@$($_.Ref)" }) -join ', '))
        }
        $pinPattern = '(?m)(?:RequiredVersion\s+\S+|@sha256:[0-9a-f]{64}|pip install [^\s]+==|GITLEAKS_VERSION|PESTER_VERSION|LYCHEE_VERSION|ACTIONLINT_VERSION)'
        foreach ($path in @((Join-Path $Root '.gitlab-ci.yml')) + @((Get-ChildItem -LiteralPath $WorkflowDir -Filter '*.yml' -File -ErrorAction SilentlyContinue).FullName)) {
            if (-not (Test-Path -LiteralPath $path)) { continue }
            $text = [IO.File]::ReadAllText($path)
            foreach ($match in [regex]::Matches($text, $pinPattern)) {
                $problems += ("pinned tool version in $(Split-Path -Leaf $path): $($match.Value)")
            }
        }
        return $problems
    }
}

Describe 'Action reference invariants' {
    It 'Finds real references and has no pins or unknown actions' {
        $problems = @(Test-ActionRefInvariants -WorkflowDir $script:WorkflowDir -Root $script:RepoRoot)
        $problems | Should -BeNullOrEmpty
    }

    It 'Keeps the non-main exception documented next to its use' {
        $linkCheck = [IO.File]::ReadAllText((Join-Path $script:WorkflowDir 'link-check.yml'))
        $linkCheck | Should -Match '(?m)^.*master, not main'
        $linkCheck | Should -Match 'lycheeverse/lychee-action@master'
    }

    It 'Passes workflow expressions through env, never into run blocks' {
        $leaks = @()
        foreach ($file in (Get-ChildItem -LiteralPath $script:WorkflowDir -Filter '*.yml' -File)) {
            $inRun = $false
            $lineNumber = 0
            foreach ($line in ([IO.File]::ReadAllText($file.FullName) -split "`n")) {
                $lineNumber++
                if ($line -match '^\s+- (name|uses):') { $inRun = $false }
                if ($line -match '^\s+run:') { $inRun = $true }
                if ($inRun -and $line -match '\$\{\{') {
                    $leaks += "$($file.Name):$lineNumber"
                }
            }
        }
        $leaks | Should -BeNullOrEmpty -Because 'an expression inside run: can inject shell text; pass it through env:'
    }

    It 'Detects a planted SHA pin and an unmapped action' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("action-refs-" + [guid]::NewGuid().ToString('N'))
        try {
            $wf = Join-Path $tmp '.github/workflows'
            New-Item -ItemType Directory -Path $wf -Force | Out-Null
            $bad = @'
name: Planted
on: workflow_dispatch
jobs:
  bad:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@0123456789abcdef0123456789abcdef01234567
      - uses: example/unknown-action@main
'@
            [IO.File]::WriteAllText((Join-Path $wf 'bad.yml'), $bad)
            [IO.File]::WriteAllText((Join-Path $tmp '.gitlab-ci.yml'), "variables:`n  GITLEAKS_VERSION: 8.0.0`n")
            $problems = @(Test-ActionRefInvariants -WorkflowDir $wf -Root $tmp)
            ($problems -join ' ') | Should -Match 'SHA pins'
            ($problems -join ' ') | Should -Match 'outside the verified map'
            ($problems -join ' ') | Should -Match 'GITLEAKS_VERSION'
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        }
    }
}
