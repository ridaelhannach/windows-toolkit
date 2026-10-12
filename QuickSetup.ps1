<#
.SYNOPSIS
    QuickSetup.ps1 - Installer for LaptopToolkit (install, update, or uninstall).
.DESCRIPTION
    Installs LaptopToolkit as a per-user PowerShell module. Nothing outside the module folder is
    changed unless you opt in: the execution policy, desktop shortcut, and $PROFILE entry are each
    asked about (default No) or enabled with a switch.

    Re-running performs a clean update: the old module folder is removed first so deleted files
    do not linger.

    Run from a clone:   .\QuickSetup.ps1
    Run from the web:   irm <url>/QuickSetup.ps1 | iex          (defaults only; prompts for each opt-in)
    With options:       & ([scriptblock]::Create((irm <url>/QuickSetup.ps1))) -Ref v1.0.0 -AddToProfile
.PARAMETER Uninstall
    Remove the module, desktop shortcut, $PROFILE entry, and scheduled task. Logs and reports in
    ~\LaptopToolkit are kept.
.PARAMETER AddToProfile
    Add a small 'toolkit' launcher function to your PowerShell profile (no module import at startup).
.PARAMETER CreateShortcut
    Create a "Laptop Toolkit" desktop shortcut.
.PARAMETER SetExecutionPolicy
    Set the CurrentUser execution policy to RemoteSigned if scripts are currently blocked.
.PARAMETER NoPrompt
    Never ask questions; opt-in steps run only if their switch is given.
.PARAMETER Ref
    Branch or tag to download when not running from a clone. Default: main. Prefer a release tag.
.PARAMETER ExpectedSha256
    If given, the downloaded archive must match this SHA-256 hash or the install is aborted.
#>

[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$AddToProfile,
    [switch]$CreateShortcut,
    [switch]$SetExecutionPolicy,
    [switch]$NoPrompt,
    [ValidatePattern('^[A-Za-z0-9._/-]+$')]
    [string]$Ref = "main",
    [string]$ExpectedSha256
)

$ErrorActionPreference = "Stop"
$ModuleName   = "LaptopToolkit"
$RepoOwnerName = "ridaelhannach/windows-toolkit"
$MarkerStart  = "# >>> LaptopToolkit >>>"
$MarkerEnd    = "# <<< LaptopToolkit <<<"
$LegacyMarker = "# --- LaptopToolkit Autoload ---"

function Confirm-Step {
    param([string]$Question, [bool]$Enabled)
    if ($Enabled) { return $true }
    if ($NoPrompt) { return $false }
    $answer = Read-Host "$Question (y/N)"
    return ($answer -match '^(y|yes)$')
}

function Get-UserModuleRoot {
    $found = ($env:PSModulePath -split [System.IO.Path]::PathSeparator) | Where-Object {
        $_ -and ($_ -like "*$HOME*" -or ($env:USERPROFILE -and $_ -like "*$env:USERPROFILE*"))
    } | Select-Object -First 1
    if ($found) { return $found }
    $docs = [Environment]::GetFolderPath("MyDocuments")
    if ($PSVersionTable.PSEdition -eq "Core") { return (Join-Path $docs "PowerShell/Modules") }
    return (Join-Path $docs "WindowsPowerShell/Modules")
}

function Remove-ProfileEntry {
    # Removes the current marker block and the legacy autoload block. Rewrites the file only if needed.
    if (-not (Test-Path -LiteralPath $PROFILE)) { return $false }
    $lines = @(Get-Content -LiteralPath $PROFILE -ErrorAction SilentlyContinue)
    $out = New-Object System.Collections.Generic.List[string]
    $skipping = $false; $changed = $false; $skipNextImport = $false
    foreach ($l in $lines) {
        if ($l.Trim() -eq $MarkerStart) { $skipping = $true; $changed = $true; continue }
        if ($skipping) {
            if ($l.Trim() -eq $MarkerEnd) { $skipping = $false }
            continue
        }
        if ($l.Trim() -eq $LegacyMarker) { $skipNextImport = $true; $changed = $true; continue }
        if ($skipNextImport) {
            $skipNextImport = $false
            if ($l -match "Import-Module.*$ModuleName") { continue }
        }
        $out.Add($l)
    }
    if ($changed) {
        [System.IO.File]::WriteAllLines($PROFILE, $out.ToArray(), (New-Object System.Text.UTF8Encoding($false)))
    }
    return $changed
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "                 LAPTOP TOOLKIT INSTALLER                   " -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$moduleRoot = Get-UserModuleRoot
$modulePath = Join-Path $moduleRoot $ModuleName

# ---------------------------------------------------------------- Uninstall
if ($Uninstall) {
    Write-Host "`nUninstalling $ModuleName..." -ForegroundColor Yellow

    $candidates = @($modulePath)
    $docs = [Environment]::GetFolderPath("MyDocuments")
    if ($docs) {
        $candidates += (Join-Path $docs "WindowsPowerShell/Modules/$ModuleName")
        $candidates += (Join-Path $docs "PowerShell/Modules/$ModuleName")
    }
    foreach ($c in ($candidates | Select-Object -Unique)) {
        # Only delete a folder that really is this module.
        if ((Test-Path -LiteralPath (Join-Path $c "$ModuleName.psd1"))) {
            Remove-Item -LiteralPath $c -Recurse -Force
            Write-Host "  Removed module: $c" -ForegroundColor Green
        }
    }

    $desktop = [Environment]::GetFolderPath("Desktop")
    if ($desktop) {
        $lnk = Join-Path $desktop "Laptop Toolkit.lnk"
        if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force; Write-Host "  Removed desktop shortcut" -ForegroundColor Green }
    }

    if (Remove-ProfileEntry) { Write-Host "  Removed `$PROFILE entry" -ForegroundColor Green }

    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        $task = Get-ScheduledTask -TaskName "LaptopToolkit-WeeklyMaintenance" -ErrorAction SilentlyContinue
        if ($task) {
            Unregister-ScheduledTask -TaskName "LaptopToolkit-WeeklyMaintenance" -Confirm:$false
            Write-Host "  Removed scheduled task" -ForegroundColor Green
        }
    }
    Write-Host "`nDone. Logs and reports in $(Join-Path $HOME 'LaptopToolkit') were kept." -ForegroundColor Cyan
    return
}

# ------------------------------------------------------------------ Install
Write-Host "`n[1/4] Locating module files..." -ForegroundColor Yellow
$sourceSrc = $null
$cleanup = @()

if ($PSScriptRoot) {
    if (Test-Path -LiteralPath (Join-Path $PSScriptRoot "src/$ModuleName.psd1")) { $sourceSrc = Join-Path $PSScriptRoot "src" }
    elseif (Test-Path -LiteralPath (Join-Path $PSScriptRoot "$ModuleName.psd1")) { $sourceSrc = $PSScriptRoot }
}

if (-not $sourceSrc) {
    $kind = if ($Ref -match '^v?\d') { "tags" } else { "heads" }
    $zipUrl = "https://github.com/$RepoOwnerName/archive/refs/$kind/$Ref.zip"
    Write-Host "      Not running from a clone. Downloading $kind/$Ref from GitHub..." -ForegroundColor Cyan
    if ($Ref -eq "main") {
        Write-Host "      Note: 'main' moves. For a reproducible install use a release tag and -ExpectedSha256." -ForegroundColor DarkGray
    }
    $tmp = [System.IO.Path]::GetTempPath()
    $tempZip = Join-Path $tmp "$ModuleName-$([guid]::NewGuid().ToString('N')).zip"
    $tempDir = Join-Path $tmp "$ModuleName-$([guid]::NewGuid().ToString('N'))"
    $cleanup += $tempZip, $tempDir
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip -UseBasicParsing
        if ($ExpectedSha256) {
            $actual = (Get-FileHash -LiteralPath $tempZip -Algorithm SHA256).Hash
            if ($actual -ne $ExpectedSha256.Trim().ToUpper()) {
                throw "SHA-256 mismatch. Expected $ExpectedSha256 but the download was $actual. Aborting."
            }
            Write-Host "      Archive hash verified." -ForegroundColor Green
        }
        Expand-Archive -LiteralPath $tempZip -DestinationPath $tempDir -Force
        $root = Get-ChildItem -LiteralPath $tempDir -Directory | Select-Object -First 1
        if ($root -and (Test-Path -LiteralPath (Join-Path $root.FullName "src/$ModuleName.psd1"))) { $sourceSrc = Join-Path $root.FullName "src" }
        else { throw "Could not find src/$ModuleName.psd1 in the downloaded archive." }
    } catch {
        foreach ($t in $cleanup) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Host "      Install failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    }
}

Write-Host "`n[2/4] Installing to $modulePath" -ForegroundColor Yellow
try {
    if (Test-Path -LiteralPath $modulePath) {
        if (Test-Path -LiteralPath (Join-Path $modulePath "$ModuleName.psd1")) {
            Remove-Item -LiteralPath $modulePath -Recurse -Force      # clean update; removes stale files
        } else {
            throw "$modulePath exists but does not look like a $ModuleName install. Move it aside and re-run."
        }
    }
    New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
    Copy-Item -Path (Join-Path $sourceSrc "*") -Destination $modulePath -Recurse -Force
} catch {
    Write-Host "      Install failed: $($_.Exception.Message)" -ForegroundColor Red
    foreach ($t in $cleanup) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }
    return
}
foreach ($t in $cleanup) { Remove-Item -LiteralPath $t -Recurse -Force -ErrorAction SilentlyContinue }

# Files from a browser-downloaded zip carry a "downloaded from the internet" mark that RemoteSigned blocks.
if (Get-Command Unblock-File -ErrorAction SilentlyContinue) {
    try { Get-ChildItem -LiteralPath $modulePath -Recurse -File | Unblock-File -ErrorAction SilentlyContinue }
    catch { <# not supported on this platform; harmless #> }
}

$manifestPath = Join-Path $modulePath "$ModuleName.psd1"
try {
    $null = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    Import-Module $manifestPath -Force -ErrorAction Stop
    Write-Host "      Installed and verified (module imports cleanly)." -ForegroundColor Green
} catch {
    Write-Host "      Installed, but the module failed to import: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "      If scripts are blocked, re-run with -SetExecutionPolicy." -ForegroundColor Yellow
}

# Reports/logs folder (inside your own profile only)
$reportsDir = Join-Path $HOME "$ModuleName/Reports"
if (-not (Test-Path -LiteralPath $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

# ---------------------------------------------------------------- Opt-ins
Write-Host "`n[3/4] Optional steps (each is off unless you say yes)" -ForegroundColor Yellow

# Execution policy
$effective = Get-ExecutionPolicy
if ($effective -in @("Restricted", "AllSigned", "Undefined")) {
    if (Confirm-Step "Scripts are blocked ($effective). Set CurrentUser policy to RemoteSigned?" $SetExecutionPolicy) {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Host "      Execution policy set to RemoteSigned (CurrentUser)." -ForegroundColor Green
        } catch {
            Write-Host "      Could not change it (it may be managed by policy): $($_.Exception.Message)" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "      Execution policy already allows local scripts ($effective)." -ForegroundColor DarkGray
}

# Desktop shortcut
if (Confirm-Step "Create a desktop shortcut?" $CreateShortcut) {
    try {
        $desktop = [Environment]::GetFolderPath("Desktop")
        if (-not $desktop) { throw "No Desktop folder found." }
        $lnk = Join-Path $desktop "Laptop Toolkit.lnk"
        $wsh = New-Object -ComObject WScript.Shell
        $sc = $wsh.CreateShortcut($lnk)
        $sc.TargetPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $safeManifest = $manifestPath -replace "'", "''"
        $sc.Arguments = "-NoExit -Command `"Import-Module '$safeManifest'; Start-ToolkitDashboard`""
        $sc.WorkingDirectory = $HOME
        $sc.Description = "Launch LaptopToolkit dashboard"
        $sc.Save()
        Write-Host "      Shortcut created." -ForegroundColor Green
    } catch {
        Write-Host "      Could not create the shortcut (Windows only): $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

# Profile launcher (a function, so shell start-up does not import the module)
if (Confirm-Step "Add a 'toolkit' launcher to your PowerShell profile?" $AddToProfile) {
    try {
        $profileDir = Split-Path $PROFILE -Parent
        if (-not (Test-Path -LiteralPath $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
        if (-not (Test-Path -LiteralPath $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
        $null = Remove-ProfileEntry      # replace any older entry instead of duplicating
        $safeManifest = $manifestPath -replace "'", "''"
        $block = @"

$MarkerStart
function toolkit { Import-Module '$safeManifest' -ErrorAction Stop; Start-ToolkitDashboard }
$MarkerEnd
"@
        Add-Content -LiteralPath $PROFILE -Value $block
        Write-Host "      Added to `$PROFILE. Open a new terminal and type: toolkit" -ForegroundColor Green
    } catch {
        Write-Host "      Could not update your profile: $($_.Exception.Message)" -ForegroundColor DarkGray
    }
}

Write-Host "`n[4/4] Done" -ForegroundColor Yellow
Write-Host "      Try:  Import-Module $ModuleName ; Start-ToolkitDashboard" -ForegroundColor Cyan
Write-Host "      Remove anytime with:  .\QuickSetup.ps1 -Uninstall`n" -ForegroundColor DarkGray
