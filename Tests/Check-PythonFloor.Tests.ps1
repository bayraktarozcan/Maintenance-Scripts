# Pester tests for Tools/Check-PythonFloor.ps1.
# The script is dot-sourced so its functions can be driven with fixtures;
# no test makes a network call.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:ScriptPath = Join-Path $script:Root 'Tools/Check-PythonFloor.ps1'
    . $script:ScriptPath

    $script:Calendar = [pscustomobject]@{
        '3.13' = [pscustomobject]@{ status = 'security';    end_of_life = '2029-10' }
        '3.12' = [pscustomobject]@{ status = 'security';    end_of_life = '2028-10' }
        '3.11' = [pscustomobject]@{ status = 'security';    end_of_life = '2027-10' }
        '3.10' = [pscustomobject]@{ status = 'end-of-life'; end_of_life = '2026-10-01' }
    }

    function Copy-Declarations([string]$Destination) {
        New-Item -ItemType Directory -Path (Join-Path $Destination '.github/workflows') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $Destination 'Docs') -Force | Out-Null
        Copy-Item -LiteralPath (Get-QualityPath $script:Root) -Destination (Join-Path $Destination '.github/workflows/quality.yml')
        Copy-Item -LiteralPath (Get-DocsPath $script:Root) -Destination (Join-Path $Destination 'Docs/Overview-And-Setup.md')
    }
}

Describe 'Check-PythonFloor source' {
    It 'Is a tracked tool with clean Windows PowerShell syntax' {
        Test-Path -LiteralPath $script:ScriptPath | Should -BeTrue
        $errors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'Uses TLS 1.3 when available and keeps 1.2 as the floor' {
        $names = [Enum]::GetNames([Net.SecurityProtocolType])
        $null = Set-TlsPolicy
        if ($names -contains 'Tls13') {
            ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls13) | Should -Not -Be 0
        }
        ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12) | Should -Not -Be 0
    }
}

Describe 'Upstream floor resolution' {
    It 'Chooses the oldest still-supported minor' {
        Get-SupportedFloor -Calendar $script:Calendar -Today ([datetime]::new(2026, 11, 21)) | Should -Be '3.11'
    }

    It 'Excludes an end-of-life status even before its date' {
        $copy = [pscustomobject]@{
            '3.11' = [pscustomobject]@{ status = 'end-of-life'; end_of_life = '2027-10' }
            '3.12' = [pscustomobject]@{ status = 'security';    end_of_life = '2028-10' }
        }
        Get-SupportedFloor -Calendar $copy -Today ([datetime]::new(2026, 11, 21)) | Should -Be '3.12'
    }

    It 'Excludes a passed EOL date when the status lags' {
        $copy = [pscustomobject]@{
            '3.11' = [pscustomobject]@{ status = 'security'; end_of_life = '2026-10-01' }
            '3.12' = [pscustomobject]@{ status = 'security'; end_of_life = '2028-10' }
        }
        Get-SupportedFloor -Calendar $copy -Today ([datetime]::new(2026, 11, 21)) | Should -Be '3.12'
    }

    It 'Handles the month rollover boundary' {
        $copy = [pscustomobject]@{ '3.11' = [pscustomobject]@{ status = 'security'; end_of_life = '2027-10' } }
        Get-SupportedFloor -Calendar $copy -Today ([datetime]::new(2027, 10, 31)) | Should -Be '3.11'
        { Get-SupportedFloor -Calendar $copy -Today ([datetime]::new(2027, 11, 1)) } | Should -Throw '*no supported Python version*'
    }

    It 'Rejects an empty calendar' {
        { Get-SupportedFloor -Calendar ([pscustomobject]@{}) -Today (Get-Date) } | Should -Throw '*no supported Python version*'
    }
}

Describe 'Declared floor parity' {
    It 'Reads the floor declared in the CI workflow' {
        $text = [IO.File]::ReadAllText((Get-QualityPath $script:Root))
        Get-DeclaredFloor $text | Should -Be '3.11'
    }

    It 'Finds no drift in the live tree' {
        Test-FloorParity -RepoRoot $script:Root -Floor '3.11' | Should -BeNullOrEmpty
    }

    It 'Detects a planted drift' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("floor-drift-" + [guid]::NewGuid().ToString('N'))
        try {
            Copy-Declarations $tmp
            $path = Join-Path $tmp '.github/workflows/quality.yml'
            $text = [IO.File]::ReadAllText($path)
            $text = [regex]::Replace($text, '(?m)^(?<prefix>[ \t]*python-version:[ \t]*\|[ \t]*\r?\n[ \t]*)3\.11', '${prefix}3.12')
            [IO.File]::WriteAllText($path, $text)
            $problems = @(Test-FloorParity -RepoRoot $tmp -Floor '3.11')
            $problems.Count | Should -BeGreaterThan 0
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        }
    }
}

Describe 'Floor bump' {
    It 'Updates every declaration and refuses a downgrade' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("floor-bump-" + [guid]::NewGuid().ToString('N'))
        try {
            Copy-Declarations $tmp
            $changed = @(Set-Floor -RepoRoot $tmp -Old '3.11' -New '3.13')
            $changed.Count | Should -Be 2
            Test-FloorParity -RepoRoot $tmp -Floor '3.13' | Should -BeNullOrEmpty
            { Set-Floor -RepoRoot $tmp -Old '3.13' -New '3.11' } | Should -Throw '*refusing to downgrade*'
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
        }
    }

    It 'Writes GitHub step outputs when requested' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ("floor-output-" + [guid]::NewGuid().ToString('N'))
        $old = $env:GITHUB_OUTPUT
        try {
            Set-Content -LiteralPath $tmp -Value '' -Encoding ascii
            $env:GITHUB_OUTPUT = $tmp
            Write-GitHubOutput 'desired' '3.11'
            Write-GitHubOutput 'changed' 'false'
            $text = [IO.File]::ReadAllText($tmp)
            $text | Should -Match 'desired=3.11'
            $text | Should -Match 'changed=false'
        } finally {
            $env:GITHUB_OUTPUT = $old
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
        }
    }
}
