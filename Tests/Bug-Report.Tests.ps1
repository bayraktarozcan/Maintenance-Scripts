# Pester 5 tests for Bug-Report.ps1 (pure functions) and .bat static checks.
# No system state is mutated: filesystem tests use TestDrive, event log is never touched.

BeforeDiscovery {
    $script:BatFiles = Get-ChildItem (Join-Path $PSScriptRoot '..\Scripts') -Filter *.bat
    if ($script:BatFiles.Count -eq 0) { throw 'No .bat files found under Scripts' }
}

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..\Scripts\Bug-Report.ps1'
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:ScriptPath, [ref]$null, [ref]$errs)
    if ($errs.Count -gt 0) { throw ('Syntax errors in Bug-Report.ps1: ' + ($errs.Message -join '; ')) }
    $pred = { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }
    $fns = $ast.FindAll($pred, $true)
    foreach ($name in @('Format-HtmlSafe', 'Get-ReportConfig', 'Clean-OldReports', 'New-DarkHtmlReport')) {
        $def = @($fns | Where-Object { $_.Name -eq $name })[0]
        if (-not $def) { throw ("Function not found: $name") }
        . ([scriptblock]::Create($def.Extent.Text))
    }

    function Test-BatchParens([string]$Path) {
        $problems = @()
        $lines = [System.IO.File]::ReadAllLines($Path)
        $depth = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $l = $lines[$i]
            $s = $l -replace '\^\(', '' -replace '\^\)', ''
            $s = [regex]::Replace($s, '"[^"]*"', '')
            if ($s -match '^\s*echo[ .]') {
                if ($s -match '[()]' -and $depth -gt 0) {
                    $problems += ("line {0}: unquoted paren inside block: {1}" -f ($i + 1), $l.Trim())
                }
            }
            $depth += ([regex]::Matches($s, '\(')).Count - ([regex]::Matches($s, '\)')).Count
            if ($depth -lt 0) { $problems += ("line {0}: negative depth" -f ($i + 1)); $depth = 0 }
        }
        if ($depth -ne 0) { $problems += ("unbalanced blocks, final depth: $depth") }
        return $problems
    }
}

Describe 'Get-ReportConfig' {
    It 'Daily uses 1 day, Daily folder, keep 30' {
        $c = Get-ReportConfig -Period Daily -Until ([datetime]'2026-09-16')
        $c.Days | Should -Be 1
        $c.Folder | Should -Be 'Daily'
        $c.Prefix | Should -Be 'Bug-Report-Daily'
        $c.Keep | Should -Be 30
        $c.Window | Should -Be 'Son 24 saat'
    }
    It 'Weekly uses 7 days, Monday folder, keep 4' {
        $wed = [datetime]'2026-09-16'
        $c = Get-ReportConfig -Period Weekly -Until $wed
        $c.Days | Should -Be 7
        $c.Folder | Should -Be 'Weekly'
        $c.Keep | Should -Be 4
        $c.Subtitle | Should -Be 'Aralık: 2026-09-09 - 2026-09-16'
    }
    It 'Weekly folder starts on Monday' {
        $mon = [datetime]'2026-09-14'
        $c = Get-ReportConfig -Period Weekly -Until $mon
        $c.Subtitle | Should -Match '2026-09-14'
    }
    It 'Monthly uses 30 days, yyyy-MM context, keep 3' {
        $c = Get-ReportConfig -Period Monthly -Until ([datetime]'2026-09-16')
        $c.Days | Should -Be 30
        $c.Folder | Should -Be 'Monthly'
        $c.Keep | Should -Be 3
        $c.Subtitle | Should -Be 'Ay: 2026-09'
    }
    It 'Rejects unknown period' {
        { Get-ReportConfig -Period Yearly -Until (Get-Date) } | Should -Throw
    }
}

Describe 'Format-HtmlSafe' {
    It 'Escapes markup characters' {
        Format-HtmlSafe '<a href="x">&y</a>' | Should -Be '&lt;a href=&quot;x&quot;&gt;&amp;y&lt;/a&gt;'
    }
    It 'Returns empty for null or empty input' {
        Format-HtmlSafe '' | Should -Be ''
        Format-HtmlSafe $null | Should -Be ''
    }
    It 'Passes Turkish text through untouched' {
        Format-HtmlSafe 'çözümleme günlüğü' | Should -Be 'çözümleme günlüğü'
    }
}

Describe 'Clean-OldReports' {
    It 'Keeps newest files' {
        $root = Join-Path 'TestDrive:' 'logs'
        New-Item -ItemType Directory -Path $root | Out-Null
        1..5 | ForEach-Object {
            $p = Join-Path $root ("r{0}.html" -f $_)
            Set-Content -LiteralPath $p -Value 'x'
            (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-$_)
        }
        Clean-OldReports -Path $root -Keep 3
        @(Get-ChildItem -LiteralPath $root -Filter *.html).Count | Should -Be 3
        (Test-Path -LiteralPath (Join-Path $root 'r1.html')) | Should -Be $true
        (Test-Path -LiteralPath (Join-Path $root 'r5.html')) | Should -Be $false
    }
}

Describe 'New-DarkHtmlReport smoke' {
    It 'Renders shell with title for empty input' {
        $html = New-DarkHtmlReport -Title 'T' -Subtitle 'S' -Window 'W' -TotalEvents 0 -Events @() -GroupedByLog @() -GroupedByProvider @() -GroupedById @() -GroupedByDay @()
        $html | Should -Match '<title>T</title>'
    }
}

Describe 'Batch static checks' {
    It 'Has balanced blocks and no unquoted parens in block echoes' -ForEach $script:BatFiles {
        Test-BatchParens $_.FullName | Should -BeNullOrEmpty
    }
    It 'Never overwrites system environment variables' -ForEach $script:BatFiles {
        $bad = Select-String -LiteralPath $_.FullName -Pattern 'set "(TMP|TEMP|PATH|PATHEXT|CD|DATE|TIME|OS|COMSPEC|PROMPT|WINDIR|SYSTEMROOT|SYSTEMDRIVE|APPDATA|LOCALAPPDATA|USERPROFILE|COMPUTERNAME|USERNAME|NUMBER_OF_PROCESSORS)="'
        $bad | Should -BeNullOrEmpty
    }
    It 'Starts with @echo off and ends with pause' -ForEach $script:BatFiles {
        $lines = [System.IO.File]::ReadAllLines($_.FullName) | Where-Object { $_.Trim() -ne '' }
        $lines[0] | Should -Be '@echo off'
        $lines[-1] | Should -Be 'pause'
    }
}
