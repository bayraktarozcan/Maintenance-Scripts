# Pester 5 static contract tests for Scripts/WinGet-Upgrade.bat.
# Runtime behavior (real/elevated runs) is verified manually; these tests pin
# the static contract so it cannot rot silently: probe method, scope wiring,
# dry-run guards, step headers, per-step errorlevel logging, and the log
# skeleton. Never executes the script or winget.

BeforeAll {
    $script:BatPath = Join-Path $PSScriptRoot '..\Scripts\WinGet-Upgrade.bat'
    $script:Text = [System.IO.File]::ReadAllText($script:BatPath) -replace "`r`n", "`n"
    $script:Lines = $script:Text -split "`n"
}

Describe 'WinGet-Upgrade elevation probe' {
    It 'Uses fltmc as the primary probe' {
        $script:Text | Should -Match '(?m)^fltmc >nul 2>&1$'
    }

    It 'Does not use net session' {
        $script:Text | Should -Not -Match 'net session'
    }

    It 'Verifies the high-integrity SID S-1-16-12288' {
        $script:Text | Should -Match 'whoami /groups'
        $script:Text | Should -Match 'find "S-1-16-12288"'
    }

    It 'Falls back to Standard on conflicting signals' {
        $script:Text | Should -Match 'set "SESSION=Standart"'
        $script:Text | Should -Match 'çelişiyor; oturum standart sayıldı'
    }

    It 'Never self-elevates' {
        $script:Text | Should -Not -Match 'RunAs|Start-Process|-Verb RunAs'
    }

    It 'Never passes -ExecutionPolicy Bypass' {
        $script:Text | Should -Not -Match 'Bypass'
    }
}

Describe 'WinGet-Upgrade scope wiring' {
    It 'Defaults to user scope and selects machine when elevated' {
        $script:Text | Should -Match '(?m)^set "SCOPE=user"$'
        $script:Text | Should -Match '(?m)^if %FLT%==0 if %HIGH%==0 set "SCOPE=machine"$'
    }

    It 'Passes --scope to both upgrade invocations' {
        $invocations = @($script:Lines | Where-Object { $_ -cmatch '--scope %SCOPE%.*> "%OUT%" 2>&1' })
        $invocations.Count | Should -Be 2
    }

    It 'Keeps the existing upgrade flags' {
        $script:Text | Should -Match '--include-unknown --accept-source-agreements --accept-package-agreements'
    }

    It 'Keeps (n/3) step headers' {
        $script:Text | Should -Match '\(1/3\) winget source update'
        $script:Text | Should -Match '\(2/3\) winget upgrade --all'
        $script:Text | Should -Match '\(3/3\) winget upgrade --scope'
    }

    It 'Logs errorlevel per step and prints one closing summary' {
        $levels = @($script:Lines | Where-Object { $_ -cmatch 'errorlevel: %EL[123]%' })
        $levels.Count | Should -Be 3
        $script:Text | Should -Match 'Özet: tüm adımlar başarılı'
        $script:Text | Should -Match 'Özet: bir ya da daha çok adım hata verdi'
    }
}

Describe 'WinGet-Upgrade dry run' {
    It 'Guards steps 1 and 2 behind WG_DRYRUN' {
        $script:Text | Should -Match 'if defined WG_DRYRUN echo \[DRYRUN\] winget source update'
        $script:Text | Should -Match 'if not defined WG_DRYRUN winget upgrade --all'
    }

    It 'Always runs the list-only step' {
        $script:Text | Should -Match '(?m)^winget upgrade --scope %SCOPE% --include-unknown > "%OUT%" 2>&1$'
    }
}

Describe 'WinGet-Upgrade log skeleton' {
    It 'Starts with @echo off and ends with pause' {
        $nonEmpty = @($script:Lines | Where-Object { $_.Trim() -ne '' })
        $nonEmpty[0] | Should -Be '@echo off'
        $nonEmpty[-1] | Should -Be 'pause'
    }

    It 'Keeps the timestamp, log folder, index, and BOM stamp' {
        $script:Text | Should -Match 'yyyyMMdd_HHmmss'
        $script:Text | Should -Match 'Logs\\WinGet-Upgrade'
        $script:Text | Should -Match 'index\.txt'
        $script:Text | Should -Match '0xEF,0xBB,0xBF'
    }
}
