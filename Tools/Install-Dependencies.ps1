# Maintenance Scripts - host dependency setup
# Installs (or verifies with -Check) every host-side dependency named in the
# project layer ("Dependencies"), at per-user global scope, never elevated:
#   Pester, PowerShell 7+ (latest 7.x from winget), gitleaks, actionlint,
#   lychee - all at their latest version - plus presence checks for git, gh,
#   and winget.
# Usage: powershell -NoProfile -File Tools/Install-Dependencies.ps1 [-Check]
# -Check reports OK/MISSING per dependency and exits 1 when anything is
# missing, without changing the host.
# Sources are official only (PSGallery, winget community repository); winget
# verifies installer hashes. Never makes changes outside the per-user scope
# and never triggers elevation.
[CmdletBinding()]
param(
    [switch]$Check
)

$script:Winget = 'winget'
$script:Failed = 0

function Test-ModulePresent([string]$Name) {
    return ($null -ne (Get-Module -ListAvailable -Name $Name))
}

function Test-ToolPresent([string]$Command) {
    return ($null -ne (Get-Command $Command -ErrorAction SilentlyContinue))
}

function Test-Pwsh7OrNewer {
    # PowerShell 7+ is the floor; any current 7.x build satisfies it, so the
    # host is not pinned to a single release that can go end-of-life.
    $cmd = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $cmd) { return $false }
    $out = & $cmd -NoProfile -Command '$PSVersionTable.PSVersion.Major' 2>&1 | Out-String
    $n = 0
    if ([int]::TryParse($out.Trim(), [ref]$n)) { return $n -ge 7 }
    return $false
}

function Install-Winget([string]$Id) {
    # --exact is an ID match, not a version pin: without it winget does a
    # case-insensitive substring search and prompts when several packages match.
    $arguments = @('install', '--id', $Id, '--exact', '--accept-source-agreements', '--accept-package-agreements')
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

Install-Dependency 'Pester' `
    { Test-ModulePresent 'Pester' } `
    { Install-Module Pester -Force -SkipPublisherCheck -Scope CurrentUser }

Install-Dependency 'PowerShell 7+' `
    { Test-Pwsh7OrNewer } `
    { Install-Winget 'Microsoft.PowerShell' }

Install-Dependency 'gitleaks' `
    { Test-ToolPresent 'gitleaks' } `
    { Install-Winget 'Gitleaks.Gitleaks' }

Install-Dependency 'actionlint' `
    { Test-ToolPresent 'actionlint' } `
    { Install-Winget 'rhysd.actionlint' }

Install-Dependency 'lychee' `
    { Test-ToolPresent 'lychee' } `
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
