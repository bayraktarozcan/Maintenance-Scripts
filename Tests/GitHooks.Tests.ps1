# The bundled pre-push hook must run the same local gate CI declares, not only
# the commit-message encoding check.

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:Hook = Join-Path $script:RepoRoot '.githooks/pre-push'
    $script:Gate = Join-Path $script:RepoRoot 'Tools/Invoke-Gate.ps1'
}

Describe 'Pre-push gate invariants' {
    It 'Keeps the tracked hook and gate files' {
        Test-Path -LiteralPath $script:Hook | Should -BeTrue
        Test-Path -LiteralPath $script:Gate | Should -BeTrue
    }

    It 'Runs the local gate after the per-ref mojibake checks' {
        $text = [IO.File]::ReadAllText($script:Hook)
        $text | Should -Match 'Check-Mojibake\.ps1'
        $text | Should -Match '-Commits -CommitRange'
        $text | Should -Match 'Tools/Invoke-Gate\.ps1'
        $mojibakeAt = $text.IndexOf('Check-Mojibake.ps1 -Commits')
        $gateAt = $text.IndexOf('Tools/Invoke-Gate.ps1')
        $gateAt | Should -BeGreaterThan $mojibakeAt
        $text | Should -Match 'pre-push: local gate failed'
    }

    It 'Fails the push when the gate fails' {
        $text = [IO.File]::ReadAllText($script:Hook)
        $text | Should -Match 'if ! "\$PS" -NoProfile -File "\$root/Tools/Invoke-Gate\.ps1"'
        $text | Should -Match 'failed=1'
    }
}
