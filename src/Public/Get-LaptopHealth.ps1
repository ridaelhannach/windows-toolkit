function Get-LaptopHealth {
    <#
    .SYNOPSIS
        Retrieves real-time system performance, uptime, battery status, and storage volume health.
    .DESCRIPTION
        Queries CIM instances for operating system uptime, CPU load, memory utilization,
        battery telemetry, and volume storage metrics.
    .OUTPUTS
        PSCustomObject containing system health metrics.
    #>
    [CmdletBinding()]
    param(
        [switch]$PassThru
    )

    $cfg = Get-ToolkitConfig
    $os = Get-CimInstance Win32_OperatingSystem
    $uptime = (Get-Date) - $os.LastBootUpTime

    $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    if ($null -eq $cpu) { $cpu = 0 }

    $totalRamGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeRamGB  = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRamGB  = [math]::Round($totalRamGB - $freeRamGB, 2)
    $ramPct     = if ($totalRamGB -gt 0) { [math]::Round(($usedRamGB / $totalRamGB) * 100, 1) } else { 0 }

    $battery = Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue
    $batteryInfo = if ($battery) {
        $statusStr = switch ($battery.BatteryStatus) {
            1 { "Discharging" }
            2 { "On AC (Charging)" }
            3 { "Fully Charged" }
            default { "Active" }
        }
        [PSCustomObject]@{
            Percent = $battery.EstimatedChargeRemaining
            Status  = $statusStr
        }
    } else {
        [PSCustomObject]@{
            Percent = $null
            Status  = "Desktop / AC-Only"
        }
    }

    $volumes = Get-Volume -ErrorAction SilentlyContinue | Where-Object DriveLetter | ForEach-Object {
        $totGB = if ($_.Size -gt 0) { [math]::Round($_.Size / 1GB, 2) } else { 0 }
        $freeGB = if ($_.SizeRemaining -gt 0) { [math]::Round($_.SizeRemaining / 1GB, 2) } else { 0 }
        $pctFree = if ($totGB -gt 0) { [math]::Round(($freeGB / $totGB) * 100, 1) } else { 0 }
        $volStatus = if ($totGB -gt 0 -and $pctFree -lt $cfg.Thresholds.diskFreeWarningPercent) { "LOW SPACE" } else { "OK" }
        [PSCustomObject]@{
            DriveLetter = "$($_.DriveLetter):"
            Label       = $_.FileSystemLabel
            FreeGB      = $freeGB
            TotalGB     = $totGB
            PercentFree = $pctFree
            Status      = $volStatus
        }
    }

    $result = [PSCustomObject]@{
        ComputerName = $env:COMPUTERNAME
        OSCaption    = $os.Caption
        OSBuild      = $os.BuildNumber
        Uptime       = $uptime
        CpuLoadPct   = $cpu
        TotalRamGB   = $totalRamGB
        UsedRamGB    = $usedRamGB
        FreeRamGB    = $freeRamGB
        RamUsedPct   = $ramPct
        Battery      = $batteryInfo
        Volumes      = $volumes
    }

    if ($PassThru) {
        return $result
    }

    # Console display formatting
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                 SYSTEM HEALTH MONITOR                      " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ("Host:            {0}" -f $result.ComputerName)
    Write-Host ("OS Version:      {0} (Build {1})" -f $result.OSCaption, $result.OSBuild)
    Write-Host ("Uptime:          {0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes)

    $cpuColor = if ($cpu -ge $cfg.Thresholds.cpuCriticalPercent) { "Red" } elseif ($cpu -ge $cfg.Thresholds.cpuWarningPercent) { "Yellow" } else { "Green" }
    Write-Host "CPU Load:        " -NoNewline
    Write-Host "$cpu%" -ForegroundColor $cpuColor

    $ramColor = if ($ramPct -ge $cfg.Thresholds.ramCriticalPercent) { "Red" } elseif ($ramPct -ge $cfg.Thresholds.ramWarningPercent) { "Yellow" } else { "Green" }
    Write-Host "Memory:          " -NoNewline
    Write-Host "$usedRamGB GB / $totalRamGB GB ($ramPct% utilized)" -ForegroundColor $ramColor

    if ($batteryInfo.Percent -ne $null) {
        $batColor = if ($batteryInfo.Percent -lt 20) { "Red" } else { "Green" }
        Write-Host "Battery:         " -NoNewline
        Write-Host ("{0}% ({1})" -f $batteryInfo.Percent, $batteryInfo.Status) -ForegroundColor $batColor
    } else {
        Write-Host "Battery:         $($batteryInfo.Status)" -ForegroundColor DarkGray
    }

    Write-Host "`n--- Storage Volumes ---" -ForegroundColor Yellow
    $volumes | Format-Table -AutoSize
}
