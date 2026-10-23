# Maintenance Scripts - host dependency setup
# Installs (or verifies with -Check) every host-side dependency named in the
# project layer ("Dependencies"), at per-user global scope, never elevated:
#   Pester 5.7.1, PowerShell 7.6.8, gitleaks 8.30.1, actionlint 1.7.12,
#   lychee 0.24.2, plus presence checks for git, gh, and winget.
# Usage: powershell -NoProfile -File Tools/Install-Dependencies.ps1 [-Check]
# -Check reports OK/MISSING per dependency and exits 1 when anything is
# missing or version-mismatched, without changing the host.
# Sources are official only (PSGallery, winget community repository) with
# exact versions; winget verifies installer hashes. Never makes changes
# outside the per-user scope and never triggers elevation.
[CmdletBinding()]
param(
    [switch]$Check
)

$script:Winget = 'winget'
$script:Failed = 0

function Test-ModuleVersion([string]$Name, [string]$Version) {
    $found = Get-Module -ListAvailable -Name $Name | Where-Object { $_.Version -eq $Version }
    return ($null -ne $found)
}

function Test-ToolVersion([string]$Command, [string[]]$Arguments, [string]$Pattern) {
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    $out = (& $cmd @Arguments 2>&1 | Out-String).Replace("`r", '')
    return ($out -match $Pattern)
}

function Test-PwshVersion([string]$Version) {
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    $out = & $cmd -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1 | Out-String
    return ($out.Trim() -eq $Version)
}

function Install-Winget([string]$Id, [string]$Version) {
    $arguments = @('install', '--exact', '--id', $Id, '--accept-source-agreements', '--accept-package-agreements')
    if ($Version) { $arguments += @('--version', $Version) }
    & $script:Winget @arguments
    if ($LASTEXITCODE -ne 0) { throw ("winget install failed for " + $Id) }
}

function Install-Dependency([string]$Name, [scriptblock]$Probe, [scriptblock]$Setup) {
    if (& $Probe) {
        Write-Output ("[ok] " + $Name)
        return
    }
    if ($Check) {
        $script:Failed = 1
        Write-Output ("[MISSING] " + $Name)
        return
    }
    Write-Output ("[..] installing " + $Name)
    & $Setup
    if (& $Probe) {
        Write-Output ("[ok] " + $Name)
    } else {
        $script:Failed = 1
        Write-Output ("[FAIL] " + $Name + " still missing after install")
    }
}

Install-Dependency 'Pester 5.7.1' `
    { Test-ModuleVersion 'Pester' '5.7.1' } `
    { Install-Module Pester -RequiredVersion 5.7.1 -Force -SkipPublisherCheck -Scope CurrentUser }

Install-Dependency 'PowerShell 7.6.8' `
    { Test-PwshVersion '7.6.8' } `
    { Install-Winget 'Microsoft.PowerShell' '7.6.8' }

Install-Dependency 'gitleaks 8.30.1' `
    { Test-ToolVersion 'gitleaks' @('version') '(?m)^8\.30\.1$' } `
    { Install-Winget 'Gitleaks.Gitleaks' }

Install-Dependency 'actionlint 1.7.12' `
    { Test-ToolVersion 'actionlint' @('--version') '(?m)^1\.7\.12$' } `
    { Install-Winget 'rhysd.actionlint' }

Install-Dependency 'lychee 0.24.2' `
    { Test-ToolVersion 'lychee' @('--version') 'lychee 0\.24\.2' } `
    { Install-Winget 'lycheeverse.lychee' }

Install-Dependency 'git' `
    { $null -ne (Get-Command git -ErrorAction SilentlyContinue) } `
    { Install-Winget 'Git.Git' }

Install-Dependency 'gh' `
    { $null -ne (Get-Command gh -ErrorAction SilentlyContinue) } `
    { Install-Winget 'GitHub.cli' }

Install-Dependency 'winget' `
    { $null -ne (Get-Command winget -ErrorAction SilentlyContinue) } `
    { throw "winget itself is missing; install App Installer from the Microsoft Store" }

if ($script:Failed -ne 0) {
    if ($Check) { Write-Output "Check FAILED" } else { Write-Output "Setup FAILED" }
    exit 1
}
if ($Check) { Write-Output "Check passed" } else { Write-Output "Setup passed" }
exit 0
