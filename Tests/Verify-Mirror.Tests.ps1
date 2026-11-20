# verify_mirror.py - fixture suite and real-file verification
# The verifier is a developer-side tool: no network, no elevation.
# Python is a host dependency; when it is missing the tests skip rather than fail.

Describe 'verify_mirror.py' {
    BeforeAll {
        $script:Root = Split-Path -Parent $PSScriptRoot
        $script:Verifier = Join-Path $script:Root 'Tools\verify_mirror.py'
        $script:Python = $null
        $cmd = Get-Command python -ErrorAction SilentlyContinue
        if (-not $cmd) { $cmd = Get-Command py -ErrorAction SilentlyContinue }
        if ($cmd) { $script:Python = $cmd.Source }
    }

    It 'exists as a tracked tool' {
        Test-Path -LiteralPath $script:Verifier | Should -BeTrue
    }

    It 'passes its built-in fixture suite' {
        if (-not $script:Python) { Set-ItResult -Skipped -Because 'python is not installed'; return }
        $output = & $script:Python $script:Verifier --selftest 2>&1
        $code = $LASTEXITCODE
        $output = $output | Out-String
        if ($code -ne 0) { Write-Host $output }
        $code | Should -Be 0
        $output | Should -Match '16/16 cases passed'
    }

    It 'detects drift in a real pair when the mirror marker is tampered' {
        if (-not $script:Python) { Set-ItResult -Skipped -Because 'python is not installed'; return }
        $canonical = Join-Path $script:Root 'AGENTS.md'
        if (-not (Test-Path -LiteralPath $canonical)) {
            Set-ItResult -Skipped -Because 'canonical document is absent'
            return
        }
        # A temp copy with a corrupted marker must produce a nonzero exit.
        # Use the OS temp dir: Logs/ is gitignored and absent in a fresh CI checkout.
        $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('mirror-tamper-' + [guid]::NewGuid().ToString('N') + '.md')
        $text = Get-Content -LiteralPath $canonical -Raw -Encoding UTF8
        $text = $text -replace 'sync-sha=[0-9a-f]{40}', ('sync-sha=' + ('0' * 40))
        [System.IO.File]::WriteAllText($tmp, $text, (New-Object System.Text.UTF8Encoding($false)))
        try {
            $null = & $script:Python $script:Verifier $canonical $tmp 2>&1
            $LASTEXITCODE | Should -Not -Be 0
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'honors --allow-missing when the mirror is intentionally absent' {
        if (-not $script:Python) { Set-ItResult -Skipped -Because 'python is not installed'; return }
        $canonical = Join-Path $script:Root 'AGENTS.md'
        if (-not (Test-Path -LiteralPath $canonical)) {
            Set-ItResult -Skipped -Because 'canonical document is absent'
            return
        }
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) ('mirror-absent-' + [guid]::NewGuid().ToString('N') + '.md')
        Remove-Item -LiteralPath $missing -Force -ErrorAction SilentlyContinue
        $null = & $script:Python $script:Verifier $canonical $missing --allow-missing 2>&1
        $LASTEXITCODE | Should -Be 0
    }
}
