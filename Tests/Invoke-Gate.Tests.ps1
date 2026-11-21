# Pester 5 tests for Tools/Invoke-Gate.ps1.
# Only the side-effect-free -List mode is executed; full gate runs stay manual/CI.

BeforeAll {
    $script:Root = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, '..'))
    $script:GatePath = [System.IO.Path]::Combine($script:Root, 'Tools', 'Invoke-Gate.ps1')
    $script:WorkflowDir = [System.IO.Path]::Combine($script:Root, '.github', 'workflows')
    $errs = $null
    $toks = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($script:GatePath, [ref]$toks, [ref]$errs)
    if ($errs.Count -gt 0) { throw ('Syntax errors in Invoke-Gate.ps1: ' + ($errs.Message -join '; ')) }
    $script:PsExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    $script:CheckSources = [ordered]@{
        Syntax     = @{ File = 'validate.yml';   Step = 'PowerShell syntax check' }
        Whitespace = @{ File = 'validate.yml';   Step = 'Trailing whitespace in added lines' }
        Mojibake   = @{ File = 'validate.yml';   Step = 'Mojibake scan (tracked files)' }
        Commits    = @{ File = 'validate.yml';   Step = 'Mojibake scan (pushed commits)' }
        Pester     = @{ File = 'quality.yml';    Step = 'Run Pester' }
        Hygiene    = @{ File = 'hygiene.yml';    Step = 'Run actionlint' }
        LinkCheck  = @{ File = 'link-check.yml'; Step = 'Check links' }
    }
    $script:ExemptWorkflows = [ordered]@{
        'secret-scan.yml' = 'Runs gitleaks over repository history in CI; no local gate equivalent.'
        'text-audit.yml'  = 'Fetches platform metadata over the network; CI-only weekly audit.'
    }
}

Describe 'GitLab CI mirror' {
    BeforeAll {
        $script:GitLabPath = [System.IO.Path]::Combine($script:Root, '.gitlab-ci.yml')
        $script:GitLabText = [System.IO.File]::ReadAllText($script:GitLabPath)
    }

    It 'Mirrors every quality gate job' {
        foreach ($job in @('validate', 'quality', 'hygiene', 'linkcheck', 'secret_scan', 'text_audit')) {
            $script:GitLabText | Should -Match ('(?m)^' + $job + ':') -Because "$job must run on GitLab too"
        }
    }

    It 'Resolves images and tools at latest instead of pinning them' {
        $script:GitLabText | Should -Match 'powershell:latest'
        $script:GitLabText | Should -Match 'golang:alpine'
        $script:GitLabText | Should -Match 'alpine:latest'
        $script:GitLabText | Should -Not -Match '@v\d+\.'
        $script:GitLabText | Should -Not -Match ':\d+\.\d+(\.\d+)?\s*$'
    }

    It 'Installs Go tools at latest' {
        $script:GitLabText | Should -Match 'actionlint/cmd/actionlint@latest'
        $script:GitLabText | Should -Match 'gitleaks/v8@latest'
    }

    It 'Installs lychee from its checksum-verified release, not as a Go module' {
        $script:GitLabText | Should -Not -Match 'go install \S*lychee'
        $script:GitLabText | Should -Match 'lycheeverse/lychee/releases/latest'
        $script:GitLabText | Should -Match 'sha256sum -c'
        $script:GitLabText | Should -Match 'x86_64-unknown-linux-musl'
        $script:GitLabText | Should -Match 'aarch64-unknown-linux-musl'
    }
}

Describe 'Invoke-Gate' {
    It 'Reports exactly the mapped check names' {
        $names = & $script:PsExe -NoProfile -File $script:GatePath -List
        $names | Should -Be @($script:CheckSources.Keys)
    }

    It 'Exits 0 in list mode' {
        & $script:PsExe -NoProfile -File $script:GatePath -List > $null
        $LASTEXITCODE | Should -Be 0
    }

    It 'Maps every gate check to a workflow step' {
        foreach ($check in $script:CheckSources.Keys) {
            $source = $script:CheckSources[$check]
            $workflowPath = [System.IO.Path]::Combine($script:WorkflowDir, $source.File)
            Test-Path -LiteralPath $workflowPath | Should -BeTrue -Because "$check maps to $($source.File)"
            $workflowText = [System.IO.File]::ReadAllText($workflowPath)
            $stepPattern = '(?m)^\s*-\s+name:\s+' + [regex]::Escape($source.Step) + '\s*$'
            $workflowText | Should -Match $stepPattern -Because "$check maps to the '$($source.Step)' step"
        }
    }

    It 'Declares exactly the mapped and exempt workflow files' {
        $workflowFiles = @(Get-ChildItem -LiteralPath $script:WorkflowDir -Filter '*.yml' -File | ForEach-Object { $_.Name } | Sort-Object)
        $mappedFiles = @($script:CheckSources.Values | ForEach-Object { $_.File })
        $exemptFiles = @($script:ExemptWorkflows.Keys)
        $expectedFiles = @(($mappedFiles + $exemptFiles) | Sort-Object -Unique)
        $workflowFiles | Should -Be $expectedFiles
        foreach ($file in $script:ExemptWorkflows.Keys) {
            $script:ExemptWorkflows[$file] | Should -Not -BeNullOrEmpty -Because "$file needs a reason"
        }
    }

    It 'Fails instead of skipping when a gate tool is missing' {
        $gateText = [System.IO.File]::ReadAllText($script:GatePath)
        $gateText | Should -Not -Match '\[skip\]'
        $gateText | Should -Match 'actionlint is not installed; run Tools/Install-Dependencies\.ps1'
        $gateText | Should -Match 'lychee is not installed; run Tools/Install-Dependencies\.ps1'
    }

    It 'Does not claim the gate avoids the network' {
        $gateText = [System.IO.File]::ReadAllText($script:GatePath)
        $gateText | Should -Not -Match 'Never makes network calls'
        $gateText | Should -Match 'fetches URLs'
    }
}
