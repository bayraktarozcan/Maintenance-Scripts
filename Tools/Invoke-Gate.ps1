# Maintenance Scripts - local quality gate
# Runs the same checks the CI definition declares
# (.github/workflows/validate.yml + quality.yml):
#   Syntax     - PowerShell parser over every .ps1 file in the tree
#   Whitespace - trailing-whitespace scan of added lines (HEAD)
#   Mojibake   - Tools/Check-Mojibake.ps1 -Files (tracked files)
#   Pester     - ./Tests suite (requires Pester 5.7.1)
# Usage: powershell -NoProfile -File Tools/Invoke-Gate.ps1 [-List]
# -List prints the check names without running them (for parity tests).
# Exits 0 when every check passes, 1 otherwise. Never makes network calls.
[CmdletBinding()]
param(
    [switch]$List
)

$script:Checks = @('Syntax', 'Whitespace', 'Mojibake', 'Pester')

if ($List) {
    $script:Checks
    return
}

$script:Root = Split-Path -Parent $PSScriptRoot
$script:Failed = 0
$script:PsExe = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }

function Invoke-GateStep([string]$Name, [scriptblock]$Body) {
    Write-Output ("[..] " + $Name)
    try {
        & $Body
        Write-Output ("[ok] " + $Name)
    } catch {
        $script:Failed = 1
        Write-Output ("[FAIL] " + $Name + ": " + $_.Exception.Message)
    }
}

Invoke-GateStep 'Syntax' {
    $errs = $null
    Get-ChildItem -Recurse -Filter *.ps1 -Path $script:Root | ForEach-Object {
        $toks = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$toks, [ref]$errs)
    }
    if ($errs.Count -gt 0) {
        $errs | ForEach-Object { Write-Output $_.Message }
        throw ($errs.Count.ToString() + " syntax errors")
    }
}

Invoke-GateStep 'Whitespace' {
    $hits = git show --format= --unified=0 HEAD | Select-String -Pattern '^\+.*[ \t]+$'
    if ($hits) {
        $hits | ForEach-Object { Write-Output $_.Line }
        throw "trailing whitespace in added lines"
    }
}

Invoke-GateStep 'Mojibake' {
    & $script:PsExe -NoProfile -File (Join-Path $script:Root 'Tools\Check-Mojibake.ps1') -Files
    if ($LASTEXITCODE -ne 0) { throw "mojibake findings present" }
}

Invoke-GateStep 'Pester' {
    $pester = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq '5.7.1' }
    if (-not $pester) { throw "Pester 5.7.1 is not installed" }
    $result = Invoke-Pester -Path (Join-Path $script:Root 'Tests') -Output Detailed -PassThru
    if ($result.FailedCount -gt 0) { throw ($result.FailedCount.ToString() + " failing tests") }
}

if ($script:Failed -ne 0) {
    Write-Output "Gate FAILED"
    exit 1
}
Write-Output "Gate passed"
exit 0
