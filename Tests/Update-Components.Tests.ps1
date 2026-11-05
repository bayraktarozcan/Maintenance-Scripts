# Pester 5 static tests for Tools/Update-Components.ps1.
# Runtime behavior is verified manually; these tests pin the standing
# contract: no self-elevation, no execution-policy bypass, UTF-8 BOM logging,
# -Check mode, two-phase Plan/Result tables, Python/Node runtime updates via winget,
# robust winget table parsing (--upgrade-available + fixed-width + honest Denetlenemedi),
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
        $script:Text | Should -Match '\$ErrorActionPreference = .Stop.'
    }

    It 'Declares -Check switch parameter' {
        $script:Text | Should -Match '\[switch\]\$Check'
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

    It 'Updates global npm packages' {
        $script:Text | Should -Match '@\(.+update.+--global'
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
        $script:Text | Should -Match 'Denetlenemedi'
        $script:Text | Should -Match 'hedef sürüm denetlenemedi'
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
        $script:Text | Should -Match 'CHECK MODE: plan shown above; no changes will be made'
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

    It 'Plan table shows Eylem/Mevcut/Hedef columns' {
        $script:Text | Should -Match 'GÜNCELLEME PLANI'
        $script:Text | Should -Match 'Eylem.*Mevcut.*Hedef'
    }

    It 'Result table shows Durum/Önceki/Sonraki columns' {
        $script:Text | Should -Match 'GÜNCELLEME SONUÇLARI'
        $script:Text | Should -Match 'Durum.*Önceki.*Sonraki'
    }

    It 'Phase 1 Detection and Phase 2 Execution sections' {
        $script:Text | Should -Match 'Phase 1: Detection'
        $script:Text | Should -Match 'Phase 2: Execution'
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

    It 'Exits 1 on failure, 0 on success' {
        $script:Text | Should -Match 'exit 1'
        $script:Text | Should -Match 'exit 0'
    }
}