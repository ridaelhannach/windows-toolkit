function Test-SecurityStatus {
    <#
    .SYNOPSIS
        Audits Microsoft Defender, Windows Firewall profiles, and BitLocker encryption status.
    .DESCRIPTION
        Checks real-time protection, signature freshness, active firewall policies, and drive encryption.
    .OUTPUTS
        PSCustomObject containing security posture metrics when -PassThru is used.
    #>
    [CmdletBinding()]
    param(
        [switch]$PassThru
    )

    $defenderInfo = $null
    try {
        $def = Get-MpComputerStatus -ErrorAction Stop
        $defenderInfo = [PSCustomObject]@{
            AntivirusEnabled          = $def.AntivirusEnabled
            RealTimeProtectionEnabled = $def.RealTimeProtectionEnabled
            SignatureLastUpdated      = $def.AntivirusSignatureLastUpdated
            AntispywareEnabled        = $def.AntispywareEnabled
        }
    } catch {
        $defenderInfo = [PSCustomObject]@{
            AntivirusEnabled          = $null
            RealTimeProtectionEnabled = $null
            SignatureLastUpdated      = "Unavailable (Requires elevation or 3rd-party AV active)"
            AntispywareEnabled        = $null
        }
    }

    $firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue | Select-Object Name, Enabled

    $bitlockerInfo = try {
        Get-BitLockerVolume -ErrorAction Stop | Select-Object MountPoint, VolumeStatus, EncryptionMethod, ProtectionStatus
    } catch {
        "Requires elevated Administrator rights."
    }

    $audit = [PSCustomObject]@{
        ComputerName     = $env:COMPUTERNAME
        Defender         = $defenderInfo
        FirewallProfiles = $firewallProfiles
        BitLocker        = $bitlockerInfo
    }

    if ($PassThru) {
        return $audit
    }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                 SECURITY & COMPLIANCE AUDIT                " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    Write-Host "`n[1. Microsoft Defender Status]" -ForegroundColor Yellow
    if ($defenderInfo.AntivirusEnabled -ne $null) {
        $avColor = if ($defenderInfo.AntivirusEnabled) { "Green" } else { "Red" }
        $rtColor = if ($defenderInfo.RealTimeProtectionEnabled) { "Green" } else { "Red" }
        Write-Host "  Antivirus Active:         " -NoNewline; Write-Host "$($defenderInfo.AntivirusEnabled)" -ForegroundColor $avColor
        Write-Host "  Real-time Protection:     " -NoNewline; Write-Host "$($defenderInfo.RealTimeProtectionEnabled)" -ForegroundColor $rtColor
        Write-Host "  Signature Last Updated:   $($defenderInfo.SignatureLastUpdated)"
    } else {
        Write-Host "  Defender telemetry: $($defenderInfo.SignatureLastUpdated)" -ForegroundColor DarkGray
    }

    Write-Host "`n[2. Windows Firewall Profiles]" -ForegroundColor Yellow
    foreach ($fp in $firewallProfiles) {
        $color = if ($fp.Enabled) { "Green" } else { "Red" }
        Write-Host ("  {0,-15} Profile Enabled: " -f $fp.Name) -NoNewline
        Write-Host "$($fp.Enabled)" -ForegroundColor $color
    }

    Write-Host "`n[3. BitLocker Drive Encryption]" -ForegroundColor Yellow
    if ($bitlockerInfo -is [string]) {
        Write-Host "  $bitlockerInfo" -ForegroundColor DarkGray
    } else {
        $bitlockerInfo | Format-Table -AutoSize
    }
}
