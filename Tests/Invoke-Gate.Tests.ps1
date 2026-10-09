# Pester 5 tests for Tools/Invoke-Gate.ps1.
# Only the side-effect-free -List mode is executed; full gate runs stay manual/CI.

BeforeAll {
    $script:GatePath = Join-Path $PSScriptRoot '..\Tools\Invoke-Gate.ps1'
    $errs = $null
    $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script:GatePath, [ref]$toks, [ref]$errs)
    if ($errs.Count -gt 0) { throw ('Syntax errors in Invoke-Gate.ps1: ' + ($errs.Message -join '; ')) }
}

Describe 'Invoke-Gate -List' {
    It 'Reports exactly the CI-declared check names' {
        $names = powershell -NoProfile -File $script:GatePath -List
        $names | Should -Be @('Syntax', 'Whitespace', 'Mojibake', 'Pester')
    }

    It 'Exits 0 in list mode' {
        powershell -NoProfile -File $script:GatePath -List > $null
        $LASTEXITCODE | Should -Be 0
    }
}
