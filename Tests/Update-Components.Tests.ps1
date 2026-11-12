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

Describe 'Update-Components Check mode' {
    It 'Respects -Check switch in Run-Command' {
        $script:Text | Should -Match 'if \(\$Check\)'
        $script:Text | Should -Match '\[CHECK MODE\]'
        $script:Text | Should -Match 'return 0'
    }

    It 'Shows plan table in CHECK MODE and exits' {
        $script:Text | Should -Match 'Show-PlanTable'
        $script:Text | Should -Match 'CHECK MODE:'
        $script:Text | Should -Match 'exit 0'
    }
}

Describe 'Update-Components two-phase tables' {
    It 'Declares Plan and Result collectors' {
        $script:Text | Should -Match '\$script:Plan = @'
        $script:Text | Should -Match '\$script:Result = @'
    }

    It 'Has Show-PlanTable and Show-ResultTable functions' {
        $script:Text | Should -Match 'function Show-PlanTable'
        $script:Text | Should -Match 'function Show-ResultTable'
    }

    It 'Plan and result output are readable text (no box drawing)' {
        $script:Text | Should -Match 'Write-Log "Plan:"'
        $script:Text | Should -Match 'Write-Log "Results:"'
        $script:Text | Should -Not -Match '╔|╚|║'
    }

    It 'Shows live detection and execution phases' {
        $script:Text | Should -Match '1/2 Checking'
        $script:Text | Should -Match '2/2 Applying'
        $script:Text | Should -Match 'Python/winget|pip|npm|Node\.js'
    }
}

Describe 'Update-Components logging and structure' {
    It 'Defines Write-Log helper with timestamp and level' {
        $script:Text | Should -Match 'function Write-Log'
        $script:Text | Should -Match 'Get-Date -Format'
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