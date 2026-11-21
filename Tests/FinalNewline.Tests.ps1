# Every tracked text file must end with a line feed. .editorconfig declares
# insert_final_newline = true; this guard makes the declaration mechanical.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    function Get-FilesMissingFinalNewline {
        param([string[]]$Paths)
        $bad = @()
        foreach ($path in $Paths) {
            if ([string]::IsNullOrWhiteSpace($path)) { continue }
            $full = if ([IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $script:RepoRoot $path }
            if (-not (Test-Path -LiteralPath $full)) { continue }
            $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $full).Path)
            if ($bytes.Length -gt 0 -and $bytes[$bytes.Length - 1] -ne 10) { $bad += $path }
        }
        return $bad
    }
}

Describe 'Final newline invariants' {
    It 'Finds no tracked file without a final LF' {
        $tracked = @(git -C $script:RepoRoot ls-files)
        $tracked.Count | Should -BeGreaterThan 0 -Because 'a guard with no files has never run'
        $bad = @(Get-FilesMissingFinalNewline $tracked)
        $bad | Should -BeNullOrEmpty -Because ('these files do not end with LF: ' + ($bad -join ', '))
    }

    It 'Detects a planted file without a final LF' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('newline-' + [guid]::NewGuid().ToString('N') + '.txt')
        try {
            [IO.File]::WriteAllBytes($tmp, [Text.Encoding]::ASCII.GetBytes('body'))
            $bad = @(Get-FilesMissingFinalNewline @($tmp))
            $bad.Count | Should -Be 1
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
        }
    }
}
