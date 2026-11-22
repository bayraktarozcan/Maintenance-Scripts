# Line-ending gate: the check must pass on a clean fixture and fail on a
# planted mixed-ending file and on a declared-eol mismatch. The repair tool
# must restore the declared ending without destroying the BOM.
# A throwaway git repository is created under the git-ignored Logs/ tree.

BeforeAll {
    $script:Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Check = Join-Path $script:Root 'Tools/Check-LineEndings.ps1'
    $script:Repair = Join-Path $script:Root 'Tools/Repair-LineEndings.ps1'
    $script:PsExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $logDir = Join-Path $script:Root 'Logs'
    if (-not (Test-Path -LiteralPath $logDir)) { $null = New-Item -ItemType Directory -Path $logDir -Force }
    $script:Fixture = Join-Path $logDir ('line-endings-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $script:Fixture -Force

    $null = & git init -q $script:Fixture
    $null = & git -C $script:Fixture config user.email 'fixture@example.invalid'
    $null = & git -C $script:Fixture config user.name 'Fixture'
    Set-Content -LiteralPath (Join-Path $script:Fixture '.gitattributes') -Value '*.ps1 text eol=crlf' -Encoding ASCII
    [IO.File]::WriteAllText((Join-Path $script:Fixture 'clean.ps1'), "line1`r`nline2`r`n", (New-Object Text.UTF8Encoding($false)))
    $null = & git -C $script:Fixture add .gitattributes clean.ps1
    $null = & git -C $script:Fixture commit -q -m 'fixture'
}

AfterAll {
    Remove-Item -LiteralPath $script:Fixture -Recurse -Force -ErrorAction SilentlyContinue
}

Describe 'LineEndings gate' {
    It 'passes when every tracked file matches its declared ending' {
        $output = & $script:PsExe -NoProfile -File $script:Check -Root $script:Fixture 2>&1
        $code = $LASTEXITCODE
        $code | Should -Be 0
        ($output -join "`n") | Should -BeNullOrEmpty
    }

    It 'fails on a planted mixed-ending file' {
        $mixed = Join-Path $script:Fixture 'mixed.ps1'
        [IO.File]::WriteAllText($mixed, "a`r`nb`n", (New-Object Text.UTF8Encoding($false)))
        $null = & git -C $script:Fixture add mixed.ps1
        try {
            $output = & $script:PsExe -NoProfile -File $script:Check -Root $script:Fixture 2>&1
            $code = $LASTEXITCODE
            $code | Should -Be 1
            ($output -join "`n") | Should -Match 'MIXED mixed\.ps1'
        } finally {
            $null = & git -C $script:Fixture rm -q --cached mixed.ps1
            Remove-Item -LiteralPath $mixed -Force -ErrorAction SilentlyContinue
        }
    }

    It 'fails when a tracked file disagrees with its declared eol' {
        $bad = Join-Path $script:Fixture 'bad.ps1'
        [IO.File]::WriteAllText($bad, "a`nb`n", (New-Object Text.UTF8Encoding($false)))
        $null = & git -C $script:Fixture add bad.ps1
        $output = & $script:PsExe -NoProfile -File $script:Check -Root $script:Fixture 2>&1
        $code = $LASTEXITCODE
        $code | Should -Be 1
        ($output -join "`n") | Should -Match 'MISMATCH bad\.ps1: w/lf but attr eol=crlf'
    }

    It 'repairs the declared ending and preserves the BOM' {
        $bad = Join-Path $script:Fixture 'bad.ps1'
        [IO.File]::WriteAllText($bad, ([char]0xFEFF + "a`nb`n"), (New-Object Text.UTF8Encoding($false)))
        $null = & $script:PsExe -NoProfile -File $script:Repair -Path 'bad.ps1' -Root $script:Fixture
        $LASTEXITCODE | Should -Be 0

        $bytes = [IO.File]::ReadAllBytes($bad)
        $bytes[0..2] -join ',' | Should -Be '239,187,191'
        $crlf = 0; $bare = 0
        for ($i = 0; $i -lt $bytes.Length; $i++) {
            if ($bytes[$i] -eq 10) {
                if ($i -gt 0 -and $bytes[$i - 1] -eq 13) { $crlf++ } else { $bare++ }
            }
        }
        $crlf | Should -Be 2
        $bare | Should -Be 0

        $output = & $script:PsExe -NoProfile -File $script:Check -Root $script:Fixture 2>&1
        $code = $LASTEXITCODE
        $code | Should -Be 0
    }
}
