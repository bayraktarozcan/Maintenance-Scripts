# Pester 5 static tests for Tools/Update-Components.ps1.
# Runtime behavior is verified manually; these tests pin the standing
# contract: no self-elevation, no execution-policy bypass, UTF-8 BOM logging,
# -Check mode, two-phase Plan/Result tables, Python/Node runtime updates via winget,
# robust winget table parsing (--upgrade-available + fixed-width + honest Unknown status),
# Python winget ID resolution (Get-PythonWingetId/Resolve-PythonWingetPackage),
# pip JSON fallback text parsing, npm post-update recheck, and command patterns.
# Never executes the script or package managers.

BeforeAll {
    $script:PsPath = Join-Path $PSScriptRoot '..\Tools\Update-Components.ps1'
    $script:Text = [System.IO.File]::ReadAllText($script:PsPath) -replace "`r`n", "`n"
    $script:Lines = $script:Text -split "`n"
}

Describe 'Update-Components static hygiene' {
    It 'Never self-elevates' {
        $script:Text | Should -Not -Match 'RunAs|Start-Process|-Verb RunAs'
    }

    It 'Never passes -ExecutionPolicy Bypass' {
        $script:Text | Should -Not -Match 'Bypass'
    }

    It 'Uses CmdletBinding and Stop error action' {
        $script:Text | Should -Match '\[CmdletBinding\(\)\]'
        $script:Text | Should -Match '\$ErrorActionPreference\s*=\s*.Stop.'
    }

    It 'Declares -Check and -ReportPath parameters' {
        $script:Text | Should -Match '\[switch\]\$Check'
        $script:Text | Should -Match '\[string\]\$ReportPath'
    }
}

Describe 'Update-Components JSON report and pip fallback' {
    It 'Defines JSON report writer and schema fields' {
        $script:Text | Should -Match 'function Write-UpdateComponentsReport'
        $script:Text | Should -Match 'schemaVersion\s*=\s*1'
        $script:Text | Should -Match 'executionCompleted'
        $script:Text | Should -Match "ConvertTo-Json -Depth 8"
        $script:Text | Should -Match 'JSON report written'
    }

    It 'Writes report for check and execute modes without making check-mode changes' {
        $script:Text | Should -Match 'Write-UpdateComponentsReport -ExecutionCompleted:\$false'
        $script:Text | Should -Match 'Write-UpdateComponentsReport -ExecutionCompleted:\$true'
        $script:Text | Should -Match 'if \(\$Check\) \{[\s\S]*?Write-UpdateComponentsReport[\s\S]*?exit 0'
    }

    It 'Uses pip --report first and pip index versions fallback without fast-deps' {
        $script:Text | Should -Match 'pip install --upgrade --dry-run --ignore-installed --report'
        $script:Text | Should -Match "function Get-LatestFromIndexVersions"
        $script:Text | Should -Match 'py -m pip index versions pip'
        $script:Text | Should -Match 'fast-deps is not a supported --use-feature on pip 26\.x'
        $script:Text | Should -Not -Match '--use-feature(?:=|\s+)fast-deps'
    }
}

Describe 'Update-Components command patterns' {
    It 'Upgrades Python runtime via winget with detected/resolved ID' {
        $script:Text | Should -Match 'Get-PythonWingetId'
        $script:Text | Should -Match 'Resolve-PythonWingetPackage'
        $script:Text | Should -Match 'Get-WingetPackageStatus'
        $script:Text | Should -Match '@\(.+upgrade.+--id.+pyExecId.+--exact.+--accept-source-agreements.+--accept-package-agreements'
    }

    It 'Resolves Python winget package and handles ID/display mismatches' {
        $script:Text | Should -Match 'function Resolve-PythonWingetPackage'
        $script:Text | Should -Match 'Python\.PythonInstallManager'
        $script:Text | Should -Match 'NameQuery'
    }

    It 'Upgrades pip via py -m pip install --upgrade pip' {
        $script:Text | Should -Match '@\(.+-m.+pip.+install.+--upgrade.*pip.'
    }

    It 'Lists outdated pip packages with JSON format' {
        $script:Text | Should -Match 'pip list --outdated --format=json'
    }

    It 'Uses Get-PipOutdated helper for package detection' {
        $script:Text | Should -Match 'function Get-PipOutdated'
        $script:Text | Should -Match 'ConvertFrom-Json'
    }

    It 'Upgrades each outdated pip package by name' {
        $script:Text | Should -Match '@\(.+-m.+pip.+install.+--upgrade'
    }

    It 'Upgrades npm globally to latest' {
        $script:Text | Should -Match '@\(.+install.+--global.+npm@latest'
    }

    It 'Upgrades global npm packages to latest' {
        $script:Text | Should -Match 'npm.+install.+--global.+\$name@\$toVer'
        $script:Text | Should -Match 'Get-NpmOutdatedGlobal'
        $script:Text | Should -Not -Match "npm', @\('update', '--global'\)"
    }

    It 'Upgrades Node.js LTS via winget' {
        $script:Text | Should -Match 'OpenJS\.NodeJS\.LTS'
        $script:Text | Should -Match '@\(.+upgrade.+--id.+nodeExecId.+--exact.+--accept-source-agreements.+--accept-package-agreements'
    }

    It 'Uses robust winget parsing and honest unknown handling' {
        $script:Text | Should -Match 'function ConvertFrom-WingetTable'
        $script:Text | Should -Match 'function Get-WingetTableField'
        $script:Text | Should -Match 'function Invoke-WingetList'
        $script:Text | Should -Match 'function Resolve-WingetPackage'
        $script:Text | Should -Match 'function Get-WingetPackageStatus'
        $script:Text | Should -Match '--upgrade-available'
        $script:Text | Should -Match 'Microsoft\.WinGet\.Client'
        $script:Text | Should -Match "'Unknown'|Unknown"
        $script:Text | Should -Match 'target version not determined'
    }

    It 'Retains Check-WingetUpdateAvailable compatibility wrapper' {
        $script:Text | Should -Match 'function Check-WingetUpdateAvailable'
        $script:Text | Should -Match 'Compatibility wrapper'
        $script:Text | Should -Match 'callers must treat \$null as unknown'
    }
}

Describe 'Update-Components host tools' {
    BeforeAll {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:PsPath, [ref]$tokens, [ref]$errors)
        $definition = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'Compare-ToolVersion'
        }, $true)
        if (-not $definition) { throw 'Compare-ToolVersion not found' }
        . ([scriptblock]::Create($definition.Extent.Text))
    }

    It 'Covers gitleaks, actionlint, lychee, PowerShell 7 and Pester' {
        $script:Text | Should -Match '\$script:HostToolWingetIds = @\{'
        $script:Text | Should -Match "'gitleaks'\s*=\s*'Gitleaks\.Gitleaks'"
        $script:Text | Should -Match "'actionlint'\s*=\s*'rhysd\.actionlint'"
        $script:Text | Should -Match "'lychee'\s*=\s*'lycheeverse\.lychee'"
        $script:Text | Should -Match "foreach \(\`$tool in @\('gitleaks', 'actionlint', 'lychee'\)\)"
        $script:Text | Should -Match "Set-Plan 'PowerShell 7'"
        $script:Text | Should -Match "Set-Plan 'Pester'"
    }

    It 'Compares versions numerically instead of as raw strings' {
        $script:Text | Should -Match 'function Compare-ToolVersion'
        $script:Text | Should -Not -Match 'Available\s+-ne\s+\$'
        $script:Text | Should -Match 'Compare-ToolVersion -Candidate \$tStatus\.Available'
        $script:Text | Should -Match 'Compare-ToolVersion -Candidate \$pwshStatus\.Available'
    }

    It 'Upgrades host tools through exact winget IDs' {
        $script:Text | Should -Match "Run-Command 'winget' @\('upgrade', '--id', \`$hid, '--exact'"
    }

    It 'Treats trailing zero components as the same version' {
        Compare-ToolVersion -Candidate '7.7.0.0' -Current '7.7.0' | Should -Be 'Same'
        Compare-ToolVersion -Candidate '7.7.0' -Current '7.7.0.0' | Should -Be 'Same'
        Compare-ToolVersion -Candidate '7.7.1' -Current '7.7.0.0' | Should -Be 'Newer'
        Compare-ToolVersion -Candidate '7.6.9' -Current '7.7.0' | Should -Be 'Older'
        Compare-ToolVersion -Candidate '' -Current '7.7.0' | Should -Be 'Unknown'
        Compare-ToolVersion -Candidate 'not installed' -Current '7.7.0' | Should -Be 'Unknown'
    }
}

Describe 'Update-Components Check mode' {
    It 'Respects -Check switch in Run-Command' {
        $script:Text | Should -Match 'if \(\$Check\)'
        $script:Text | Should -Match '\[CHECK MODE\]'
        $script:Text | Should -Match 'return 0'
    }

    It 'Closes phase 1 in CHECK MODE and exits' {
        $script:Text | Should -Match 'Show-PhaseOneTotals'
        $script:Text | Should -Match 'CHECK MODE:'
        $script:Text | Should -Match 'exit 0'
    }
}

Describe 'Update-Components two-phase tables' {
    It 'Declares Plan and Result collectors' {
        $script:Text | Should -Match '\$script:Plan = @'
        $script:Text | Should -Match '\$script:Result = @'
    }

    It 'Has Show-PlanItems and phase total functions, no duplicate tables' {
        $script:Text | Should -Match 'function Show-PlanItems'
        $script:Text | Should -Match 'function Show-PhaseOneTotals'
        $script:Text | Should -Match 'function Show-PhaseTotals'
        $script:Text | Should -Not -Match 'function Show-PlanTable'
        $script:Text | Should -Not -Match 'function Show-ResultTable'
    }

    It 'Output is readable text (no box drawing, no repeated tables)' {
        $script:Text | Should -Not -Match 'Write-Log "Plan:"'
        $script:Text | Should -Not -Match 'Write-Log "Results:"'
        $script:Text | Should -Not -Match '╔|╚|║'
    }

    It 'Prints detected package names once, where they are found' {
        $script:Text | Should -Match 'Write-Log "      - \$item"'
        $script:Text | Should -Match 'Show-PlanItems -Component ''pip packages'''
        $script:Text | Should -Match 'Show-PlanItems -Component ''pipx'''
        $script:Text | Should -Match 'Show-PlanItems -Component ''npm packages'''
        $script:Text | Should -Match '\$planRow\.Items = @\(\$outdated'
        $script:Text | Should -Match '\$planRow\.Items = \$pipxInstalledNames'
        $script:Text | Should -Match '\$planRow\.Items = @\(\$npmOutdated'
    }

    It 'Closes phase 1 with a count and the component names' {
        $script:Text | Should -Match '\$updates = @\(\$script:Plan \| Where-Object \{ \$_.Action -eq ''Update available'' \}\)'
        $script:Text | Should -Match '\$names = \(\$updates \| ForEach-Object \{ \$_.Component \}\) -join '', '''
        $script:Text | Should -Match '1/2 Found \$\(\$updates\.Count\) update\(s\): \$names'
    }

    It 'Highlights update-available rows and counts phase 2 successes' {
        $script:Text | Should -Match '\$liveLevel = if \(\$Action -eq ''Update available''\) \{ ''UPDATE'' \}'
        $script:Text | Should -Match '\$applied = @\(\$ResultRows \| Where-Object \{ \$plannedNames -contains \$_.Component -and \$_.Status -in @\(''Updated'', ''Up to date''\) \}\)'
        $script:Text | Should -Match '2/2 \$\(\$applied\.Count\) of \$\(\$planned\.Count\) component update\(s\)'
    }

    It 'Shows live detection and execution phases' {
        $script:Text | Should -Match '1/2 Checking'
        $script:Text | Should -Match '2/2 Applying'
        $script:Text | Should -Match 'Python/winget|pip|npm|Node\.js'
    }

    It 'Streams one live line per component without repeating it at the end' {
        $script:Text | Should -Match 'Write-Log "    \$\(\$Component\): \$\(\$Action\)\$range\$detail" \$liveLevel'
        $script:Text | Should -Match 'Write-Log "    \$\(\$Component\): \$\(\$Status\) \[\$after\]\$detail" \$rowLevel'
        $script:Text | Should -Match '\$planned = @\(\$script:Plan \| Where-Object \{ \$_.Component -eq \$Component -and \$_.Action -eq ''Update available'' \}\)'
        $script:Text | Should -Match 'if \(\$planned\.Count -eq 0\) \{ return \}'
        $script:Text | Should -Match 'live progress line'
        $script:Text | Should -Match 'Everything else was already shown in phase 1; repeating it is noise'
    }
}

Describe 'Update-Components logging and structure' {
    It 'Defines Write-Log helper with timestamp and level' {
        $script:Text | Should -Match 'function Write-Log'
        $script:Text | Should -Match 'Get-Date -Format'
    }

    It 'Mirrors each rendered line to the launcher log file' {
        $script:Text | Should -Match '\[string\]\$LogPath'
        $script:Text | Should -Match '\[System\.IO\.File\]::AppendAllText'
    }

    It 'Colors step, update, success, warning, and error levels' {
        $script:Text | Should -Match "'STEP'\s+\{ 'Cyan' \}"
        $script:Text | Should -Match "'UPDATE'\s+\{ 'Magenta' \}"
        $script:Text | Should -Match "'OK'\s+\{ 'Green' \}"
        $script:Text | Should -Match "'WARN'\s+\{ 'Yellow' \}"
        $script:Text | Should -Match "'ERROR'\s+\{ 'Red' \}"
    }

    It 'Logs an unhandled terminating error before exiting' {
        $script:Text | Should -Match '(?m)^trap \{'
        $script:Text | Should -Match 'Unhandled error:'
    }

    It 'Defines Test-Command helper' {
        $script:Text | Should -Match 'function Test-Command'
    }

    It 'Defines Run-Command helper with exit code handling' {
        $script:Text | Should -Match 'function Run-Command'
        $script:Text | Should -Match '\$LASTEXITCODE'
    }

    It 'Defines Get-PythonWingetId helper for version detection' {
        $script:Text | Should -Match 'function Get-PythonWingetId'
        $script:Text | Should -Match 'py --version'
        $script:Text | Should -Match 'Select-String -Pattern'
    }

    It 'Defines helper functions for version extraction' {
        $script:Text | Should -Match 'function Get-PythonVersion'
        $script:Text | Should -Match 'function Get-PipVersion'
        $script:Text | Should -Match 'function Get-NodeVersion'
        $script:Text | Should -Match 'function Get-NpmVersion'
    }

    It 'Tracks overall failure state' {
        $script:Text | Should -Match '\$script:OverallFailed'
    }

}

Describe 'Update-Components winget table parsing fixtures' {
    It 'Keeps localized header aliases for robust winget table parsing' {
        $script:Text | Should -Match "Get-WingetTableField .*@\('Version', 'Sürüm'\)"
        $script:Text | Should -Match "Get-WingetTableField .*@\('Available', 'Mevcut'\)"
        $script:Text | Should -Match "Get-WingetTableField .*@\('Name', 'Ad'\)"
    }

    It 'Parses fixed-width winget tables by separator alignment, not by English header text' {
        $script:Text | Should -Match 'Column boundaries are derived from the'
        $script:Text | Should -Match "if \(\`$Lines\[\`$i\] -match"
        $script:Text | Should -Match '\^\-\{8,\}'
    }
}

Describe 'Update-Components result collector invariant' {
    It 'Declares exactly one result collector and no generic $result assignments' {
        $collectorAssignments = {
            param([string]$Source)
            $tokens = $null; $errors = $null
            $localAst = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$tokens, [ref]$errors)
            @($localAst.FindAll({ param($n)
                $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                (($n.Left.VariablePath.UserPath -replace '^script:', '') -ieq 'result')
            }, $true))
        }

        $found = @(& $collectorAssignments $script:Text)
        $found.Count | Should -Be 1
        $found[0].Left.VariablePath.UserPath | Should -BeExactly 'script:Result'
        $found[0].Right.Extent.Text | Should -Match '^@\('

        # A check must be seen to fail: the exact collision shape is rejected.
        $planted = @(& $collectorAssignments '$script:result = 0')
        $planted.Count | Should -Be 1
        $planted[0].Left.VariablePath.UserPath | Should -Not -BeExactly 'script:Result'
        $planted[0].Right.Extent.Text | Should -Not -Match '^@\('
    }

    It 'Rejects a collector clobbered by a case-insensitive variable collision' {
        $tokens = $null; $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseInput($script:Text, [ref]$tokens, [ref]$errors)
        $errors | Should -BeNullOrEmpty

        $wanted = @('Write-Log', 'Set-Result', 'Assert-ResultCollector')
        $funcs = @($ast.FindAll({ param($n)
            $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $wanted -contains $n.Name
        }, $true))
        $funcs.Count | Should -Be 3

        $assign = { param($n)
            $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $n.Left -is [System.Management.Automation.Language.VariableExpressionAst]
        }
        $collector = @($ast.FindAll($assign, $true) | Where-Object { $_.Left.VariablePath.UserPath -eq 'script:Result' })[0]
        $names = @($ast.FindAll($assign, $true) | Where-Object { $_.Left.VariablePath.UserPath -eq 'script:ResultComponentNames' })[0]
        $collector | Should -Not -BeNullOrEmpty
        $names | Should -Not -BeNullOrEmpty

        $snippet = (@($collector.Extent.Text, $names.Extent.Text) + @($funcs | ForEach-Object { $_.Extent.Text })) -join "`n"

        # The extracted snippet writes to script scope; save and restore that
        # scope so this test cannot pollute any test that runs after it.
        $saved = @{}
        foreach ($name in @('Result', 'ResultComponentNames')) {
            $v = Get-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue
            $saved[$name] = if ($null -ne $v) { @{ Present = $true; Value = $v.Value } } else { @{ Present = $false } }
        }
        foreach ($name in @('Write-Log', 'Set-Result', 'Assert-ResultCollector')) {
            $f = Get-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
            $saved[$name] = if ($null -ne $f) { @{ Present = $true; Value = $f.ScriptBlock } } else { @{ Present = $false } }
        }

        try {
            Invoke-Expression $snippet

            foreach ($component in $script:ResultComponentNames) { Set-Result $component 'Up to date' 'x' 'x' }
            { Assert-ResultCollector -Where 'healthy' } | Should -Not -Throw

            # Field-level corruption must fail too, not only a rebound collector.
            $script:Result[0]['Status'] = ''
            { Assert-ResultCollector -Where 'empty-field' } | Should -Throw -ExpectedMessage '*ResultCollector*'
            $script:Result[0]['Status'] = 'Up to date'

            # PowerShell variable names are case-insensitive: this is the exact
            # script-scope collision that used to turn the collector into an integer.
            $script:result = 0
            { Assert-ResultCollector -Where 'collision' } | Should -Throw -ExpectedMessage '*ResultCollector*'
        } finally {
            foreach ($name in @('Result', 'ResultComponentNames')) {
                if ($saved[$name].Present) { Set-Variable -Name $name -Scope Script -Value $saved[$name].Value -Force }
                else { Remove-Variable -Name $name -Scope Script -ErrorAction SilentlyContinue }
            }
            foreach ($name in @('Write-Log', 'Set-Result', 'Assert-ResultCollector')) {
                if ($saved[$name].Present) { Set-Item -Path "Function:\$name" -Value $saved[$name].Value -Force }
                else { Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue }
            }
        }
    }
}
