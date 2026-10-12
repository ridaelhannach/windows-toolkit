function Get-StartupPrograms {
    <#
    .SYNOPSIS
        Audits startup programs configured across user and system registry hives.
    .DESCRIPTION
        Reads Run keys from HKCU and HKLM to report applications scheduled to launch at logon.
    #>
    [CmdletBinding()]
    param(
        [switch]$PassThru
    )

    $startupEntries = @()
    $regLocations = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run"
    )

    foreach ($reg in $regLocations) {
        if (Test-Path $reg) {
            $props = (Get-ItemProperty -Path $reg -ErrorAction SilentlyContinue).PSObject.Properties |
                Where-Object { $_.Name -notin @("PSPath", "PSParentPath", "PSChildName", "PSDrive", "PSProvider") }
            foreach ($p in $props) {
                $startupEntries += [PSCustomObject]@{
                    Scope       = if ($reg -match "HKCU") { "User" } else { "System" }
                    Application = $p.Name
                    Command     = $p.Value
                }
            }
        }
    }

    if ($PassThru) {
        return $startupEntries
    }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                STARTUP APPLICATIONS AUDIT                  " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    $startupEntries | Format-Table -AutoSize
}
