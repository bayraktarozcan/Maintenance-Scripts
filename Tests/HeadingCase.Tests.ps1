# Documentation headings follow the rule declared in AGENTS.md §Conventions.
# It is easy to drift from across many Markdown files, so this guard reads the
# tree instead of trusting a one-time cleanup.
# What it cannot see: HTML headings, whether a capitalized word is the right
# word, or code identifiers inside backticks (exempt by the rule).

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Minor = @('a', 'an', 'the', 'and', 'or', 'but', 'nor', 'for', 'of', 'on', 'per',
        'to', 'via', 'with', 'as', 'at', 'by', 'in', 'if', 've', 'veya', 'ya', 'ile',
        'için', 'bir', 'göre', 'den', 'dan', 'gibi', 'kadar')
    $script:Acronyms = @('ADMX', 'API', 'ASCII', 'BOM', 'CD', 'CI', 'DNS', 'GUID', 'HKLM',
        'HTML', 'HTTP', 'HTTPS', 'ID', 'IoC', 'JSON', 'JS', 'LTS', 'OS', 'PDF', 'PS1',
        'REG', 'SHA', 'SHA1', 'SHA256', 'SFC', 'TLS', 'UTC', 'URL', 'UTF8', 'XML',
        'YAML', 'ZIP', 'CSS', 'IO', 'UI', 'UX', 'AI', 'CLI', 'CDN', 'GDPR', 'CCPA')
    $script:Mixed = @('ioc', 'powershell', 'github', 'gitlab', 'dependabot', 'pester',
        'lychee', 'gitleaks', 'actionlint', 'markdown', 'javascript', 'i18n',
        'changelog', 'readme', 'wiki', 'windows', 'linux', 'git', 'codeql',
        'winget', 'pip', 'npm', 'pipx', 'node.js', 'python')

    function Get-HeadingViolations {
        param([string]$Path)
        $violations = @()
        $inFence = $false
        $lines = [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).Path)
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*(```|~~~)') { $inFence = -not $inFence; continue }
            if ($inFence -or $line -notmatch '^#{1,6}\s+(.+)$') { continue }
            $text = $Matches[1]
            $prose = [regex]::Replace($text, '`[^`]*`', '')
            if ($text -cmatch 'İ(?:s|n|f|nto|nside)\b') {
                $violations += "$($Path):$($i + 1): Turkish dotted I in English word"
            }
            if ($text -match '^\[?v?\d' -or $text -match '^\[?V\d' -or $text -match '^vX') { continue }
            $words = @($prose -split '\s+' | Where-Object { $_ -ne '' })
            for ($w = 0; $w -lt $words.Count; $w++) {
                $word = $words[$w]
                if ($word -match '[`\[<]' -or $word -match '://') { continue }
                $core = $word -replace '^[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+', '' -replace '[^A-Za-zÇĞİÖŞÜçğıöşü0-9]+$', ''
                if ($core -eq '') { continue }
                $low = $core.ToLowerInvariant()
                if ($script:Mixed -contains $low) { continue }
                if ($script:Acronyms -contains $core.ToUpperInvariant()) { continue }
                if ($script:Minor -contains $low -and $w -gt 0 -and $w -lt $words.Count - 1) { continue }
                $subs = @($core -split '[-/]') | Where-Object { $_ -ne '' }
                foreach ($sub in $subs) {
                    $subLow = $sub.ToLowerInvariant()
                    if ($script:Mixed -contains $subLow -or $script:Acronyms -contains $sub.ToUpperInvariant()) { continue }
                    if ($script:Minor -contains $subLow -and $sub -ne $subs[0]) { continue }
                    if ($sub[0] -cne $sub[0].ToString().ToUpperInvariant()) {
                        $violations += "$($Path):$($i + 1): $sub"
                    }
                }
            }
        }
        return $violations
    }
}

Describe 'Heading case invariants' {
    It 'Declares the rule in the canonical document and its mirror' {
        $canonical = [IO.File]::ReadAllText((Join-Path $script:RepoRoot 'AGENTS.md'))
        $canonical | Should -Match '\*\*Heading and abbreviation case\.\*\*'
        $mirror = Join-Path $script:RepoRoot 'AGENTS-TR.md'
        if (Test-Path -LiteralPath $mirror) {
            [IO.File]::ReadAllText((Resolve-Path -LiteralPath $mirror).Path) |
                Should -Match '\*\*Başlık ve kısaltma büyüklüğü\.\*\*'
        }
    }

    It 'Detects a planted lowercase heading and a planted dotted I' {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) ('heading-' + [guid]::NewGuid().ToString('N') + '.md')
        try {
            [IO.File]::WriteAllText($tmp, "# A Good Heading`n`n## a bad heading`n`n### What İs This`n")
            $found = @(Get-HeadingViolations $tmp)
            ($found -join ' ') | Should -Match 'bad'
            ($found -join ' ') | Should -Match 'Turkish dotted I'
        } finally {
            if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
        }
    }

    It 'Finds no violation in tracked Markdown outside code fences' {
        $found = @()
        foreach ($path in (git -C $script:RepoRoot ls-files '*.md')) {
            $full = Join-Path $script:RepoRoot $path
            if (Test-Path -LiteralPath $full) { $found += @(Get-HeadingViolations $full) }
        }
        $found | Should -BeNullOrEmpty -Because ('headings are prose: ' + ($found -join '; '))
    }
}
