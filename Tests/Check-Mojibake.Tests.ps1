# Pester 5 tests for Scripts/Check-Mojibake.ps1 (the encoding/mojibake gate).
# The script is executed as a child process so its `exit 1` contract can be
# asserted without terminating the test host. No system state is mutated:
# fixtures live under $TestDrive (a real filesystem path that native git and
# .NET file APIs can use), commit fixtures use isolated temp git repos.
# Deliberate mojibake samples are built from character codes at runtime so the
# test file itself stays clean for the encoding gate.

BeforeAll {
    $script:PsExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $script:Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $script:Check = Join-Path $PSScriptRoot '..\Scripts\Check-Mojibake.ps1'

    # Double-encoded Latin-1 samples (built from character codes so this file
    # stays clean for the encoding gate): Turkish words with Latin-1 accents.
    $script:MojiLatin1 = 'T' + [char]0xC3 + [char]0xBC + 'rk' + [char]0xC3 + [char]0xA7 + 'e metin'
    $script:MojiLatin1Staged = 'T' + [char]0xC3 + [char]0xBC + 'rk' + [char]0xC3 + [char]0xA7 + 'e bozuk'
    $script:MojiFix = 'fix: T' + [char]0xC3 + [char]0xBC + 'rk' + [char]0xC3 + [char]0xA7 + 'e bozuk'
    $script:MojiChore = 'chore: T' + [char]0xC3 + [char]0xBC + 'rk' + [char]0xC3 + [char]0xA7 + 'e'
    $script:MojiJson = 'T' + [char]0xC3 + [char]0xBC + 'rk' + [char]0xC3 + [char]0xA7 + 'e a' + [char]0xC3 + [char]0xA7 + [char]0xC4 + [char]0xB1 + 'klama'

    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script:Check, [ref]$null, [ref]$errs)
    if ($errs.Count -gt 0) { throw ('Syntax errors in Check-Mojibake.ps1: ' + ($errs.Message -join '; ')) }

    $script:RepoRoot = Split-Path $PSScriptRoot -Parent
    $script:FixtureDir = Join-Path $TestDrive 'moji'
    New-Item -ItemType Directory -Path $script:FixtureDir -Force | Out-Null

    function New-FixtureFile {
        param([string]$Name, [string]$Text, [switch]$InvalidBytes)
        $p = Join-Path $script:FixtureDir $Name
        if ($InvalidBytes) {
            [System.IO.File]::WriteAllBytes($p, [byte[]](0xC3, 0x28))
        } else {
            [System.IO.File]::WriteAllText($p, $Text, $script:Utf8NoBom)
        }
        return $p
    }

    function New-TempRepo([string]$Name) {
        $dir = Join-Path $TestDrive $Name
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & git -C $dir init -q -b main
        & git -C $dir config user.email 'tests@example.com'
        & git -C $dir config user.name 'Pester'
        return $dir
    }

    function Invoke-Check {
        param([string[]]$ArgList, [string]$Root = $script:RepoRoot)
        $out = & $script:PsExe -NoProfile -File $script:Check -Root $Root @ArgList 2>&1
        return [pscustomobject]@{ LastExit = $LASTEXITCODE; Output = ($out -join "`n") }
    }
}

Describe 'File scanning with -Path' {
    It 'flags double-encoded Latin-1 text' {
        $f = New-FixtureFile 'moji-bad.txt' $script:MojiLatin1
        $r = Invoke-Check -ArgList @('-Path', $f)
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'MOJIBAKE'
    }

    It 'flags invalid UTF-8 bytes' {
        $f = New-FixtureFile 'moji-invalid.dat' '' -InvalidBytes
        $r = Invoke-Check -ArgList @('-Path', $f)
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'INVALID-UTF8'
    }

    It 'flags the U+FFFD replacement character' {
        $f = New-FixtureFile 'moji-replacement.txt' ([string][char]0xFFFD + ' satir')
        $r = Invoke-Check -ArgList @('-Path', $f)
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'MOJIBAKE'
    }

    It 'accepts valid Turkish text plus symbols' {
        $f = New-FixtureFile 'moji-ok.txt' 'Hâlâ yardım çağrısı · öğle çözüm şekli'
        $r = Invoke-Check -ArgList @('-Path', $f)
        $r.LastExit | Should -Be 0
        $r.Output | Should -Not -Match 'MOJIBAKE'
    }

    It 'skips binary files (NUL byte probe)' {
        $p = Join-Path $script:FixtureDir 'moji-binary.bin'
        [System.IO.File]::WriteAllBytes($p, [byte[]](0x00, 0x01, 0x02, 0x43))
        $r = Invoke-Check -ArgList @('-Path', $p)
        $r.LastExit | Should -Be 0
    }

    It 'reports a missing explicit path' {
        $r = Invoke-Check -ArgList @('-Path', (Join-Path $script:FixtureDir 'does-not-exist.txt'))
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'MISSING'
    }
}

Describe 'Staged scanning (-Files -Staged)' {
    It 'scans staged files only' {
        $td = New-TempRepo 'staged-repo'
        $ok = Join-Path $td 'ok.txt'
        $bad = Join-Path $td 'bad.txt'
        [System.IO.File]::WriteAllText($ok, 'clean staged file', $script:Utf8NoBom)
        [System.IO.File]::WriteAllText($bad, $script:MojiLatin1Staged, $script:Utf8NoBom)
        & git -C $td add ok.txt
        $r = Invoke-Check -ArgList @('-Files', '-Staged') -Root $td
        $r.LastExit | Should -Be 0
        & git -C $td add bad.txt
        $r2 = Invoke-Check -ArgList @('-Files', '-Staged') -Root $td
        $r2.LastExit | Should -Be 1
    }
}

Describe 'Commit message scanning (-Commits)' {
    It 'flags a mojibake commit message' {
        $td = New-TempRepo 'commit-bad'
        $file = Join-Path $td 'file.txt'
        $msg = Join-Path $td 'msg.txt'
        [System.IO.File]::WriteAllText($file, 'content', $script:Utf8NoBom)
        [System.IO.File]::WriteAllText($msg, $script:MojiFix, $script:Utf8NoBom)
        & git -C $td add file.txt
        & git -C $td commit -q --no-verify -F $msg
        $r = Invoke-Check -ArgList @('-Commits', '-CommitRange', 'HEAD') -Root $td
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'MOJIBAKE'
    }

    It 'accepts clean (ASCII) commit messages' {
        $td = New-TempRepo 'commit-ok'
        $file = Join-Path $td 'file.txt'
        $msg = Join-Path $td 'msg.txt'
        [System.IO.File]::WriteAllText($file, 'content', $script:Utf8NoBom)
        [System.IO.File]::WriteAllText($msg, 'fix: clean message', $script:Utf8NoBom)
        & git -C $td add file.txt
        & git -C $td commit -q --no-verify -F $msg
        $r = Invoke-Check -ArgList @('-Commits', '-CommitRange', 'HEAD') -Root $td
        $r.LastExit | Should -Be 0
    }
}

Describe 'Message mode (-Message)' {
    It 'flags mojibake in the commit-msg hook file' {
        $f = New-FixtureFile 'msg-bad.txt' $script:MojiChore
        $r = Invoke-Check -ArgList @('-Message', $f)
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'MOJIBAKE'
    }

    It 'accepts a clean commit message' {
        $f = New-FixtureFile 'msg-ok.txt' 'chore: encode gate'
        $r = Invoke-Check -ArgList @('-Message', $f)
        $r.LastExit | Should -Be 0
    }
}

Describe 'JSON payload scanning (-JsonFile)' {
    It 'flags mojibake inside JSON string values' {
        $p = Join-Path $script:FixtureDir 'payload-bad.json'
        [System.IO.File]::WriteAllText($p, '{ "description": "' + $script:MojiJson + '" }', $script:Utf8NoBom)
        $r = Invoke-Check -ArgList @('-JsonFile', $p)
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'MOJIBAKE'
    }

    It 'accepts a clean JSON payload with valid Turkish' {
        $p = Join-Path $script:FixtureDir 'payload-ok.json'
        [System.IO.File]::WriteAllText($p, '{ "name": "Maintenance-Scripts", "description": "Hâlâ yardım · öğle çözüm şekli", "topics": [] }', $script:Utf8NoBom)
        $r = Invoke-Check -ArgList @('-JsonFile', $p)
        $r.LastExit | Should -Be 0
    }

    It 'reports non-JSON payload content' {
        $p = Join-Path $script:FixtureDir 'payload-notjson.json'
        [System.IO.File]::WriteAllText($p, 'plain text, no braces', $script:Utf8NoBom)
        $r = Invoke-Check -ArgList @('-JsonFile', $p)
        $r.LastExit | Should -Be 1
        $r.Output | Should -Match 'JSON-PARSE'
    }
}

Describe 'Repository regression' {
    It 'finds no mojibake in tracked files of this repository' {
        $r = Invoke-Check -ArgList @('-Files')
        $r.LastExit | Should -Be 0
        $r.Output | Should -Not -Match 'MOJIBAKE|INVALID-UTF8'
    }
}