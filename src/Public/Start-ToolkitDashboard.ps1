function Start-ToolkitDashboard {
    <#
    .SYNOPSIS
        Launches the interactive LaptopToolkit console dashboard.
    #>
    [CmdletBinding()]
    param()

    function Show-DashboardMenu {
        Clear-Host
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host "        LAPTOP TOOLKIT - AUTOMATION DASHBOARD               " -ForegroundColor Cyan
        Write-Host "============================================================" -ForegroundColor Cyan
        Write-Host ("Host: {0} | User: {1} | Date: {2}" -f $env:COMPUTERNAME, $env:USERNAME, (Get-Date -Format "yyyy-MM-dd HH:mm")) -ForegroundColor DarkGray
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host " [DIAGNOSTICS & TOOLS]" -ForegroundColor Yellow
        Write-Host "  [1] System Health Monitor (CPU, RAM, Uptime, Disks)"
        Write-Host "  [2] Security Audit (Defender, Firewall, BitLocker)"
        Write-Host "  [3] Network Diagnostics & Local Listening Ports"
        Write-Host "  [4] Developer Environment Toolchain Check"
        Write-Host "  [5] Smart Safe Disk Cleaner (Discovery / Purge)"
        Write-Host "  [6] Startup Applications Inspector"
        Write-Host "  [11] Event Log Analyzer (crashes, errors, warnings)"
        Write-Host "  [12] Wi-Fi Analyzer (signal, security, channels)"
        Write-Host "  [13] Duplicate File Finder (read-only)"
        Write-Host "  [14] Software Updates (WinGet)"
        Write-Host "  [15] Git Project Status"
        Write-Host ""
        Write-Host " [REPORTING]" -ForegroundColor Yellow
        Write-Host "  [7] Generate Responsive HTML Health Report"
        Write-Host "  [8] Generate Battery Health & Capacity Report"
        Write-Host ""
        Write-Host " [AUTOMATION & SCHEDULING]" -ForegroundColor Yellow
        Write-Host "  [9] Manage Scheduled Maintenance Task"
        Write-Host "  [10] View Recent Toolkit Activity Logs"
        Write-Host ""
        Write-Host " [Q] Quit"
        Write-Host "============================================================" -ForegroundColor Cyan
    }

    do {
        Show-DashboardMenu
        $sel = Read-Host "Select an option"
        switch ($sel) {
            '1' { Get-LaptopHealth; Pause }
            '2' { Test-SecurityStatus; Pause }
            '3' { Test-NetworkDiagnostics; Pause }
            '4' { Test-DeveloperEnvironment; Pause }
            '5' { Invoke-SafeDiskCleanup; Pause }
            '6' { Get-StartupPrograms; Pause }
            '11' { Get-EventLogSummary; Pause }
            '12' { Get-WifiStatus -ScanNearby; Pause }
            '13' {
                $default = Join-Path $HOME "Downloads"
                $dupPath = Read-Host "Folder to scan [$default]"
                if (-not $dupPath) { $dupPath = $default }
                if (Test-Path -LiteralPath $dupPath -PathType Container) { Find-DuplicateFile -Path $dupPath }
                else { Write-Host "Folder not found: $dupPath" -ForegroundColor Yellow }
                Pause
            }
            '14' { Get-SoftwareUpdate; Pause }
            '15' { Get-GitProjectStatus; Pause }
            '7' { New-HealthReport; Pause }
            '8' { New-BatteryReport; Pause }
            '9' {
                Clear-Host
                Register-ToolkitScheduledTask -Action Status
                Write-Host "`nOptions:"
                Write-Host " [1] Register Weekly Task (Sundays @ 10:00 AM)"
                Write-Host " [2] Unregister / Remove Task"
                Write-Host " [3] Run Maintenance Routine Now"
                Write-Host " [B] Back"
                $sub = Read-Host "`nSelect an option"
                switch ($sub) {
                    '1' { Register-ToolkitScheduledTask -Action Register }
                    '2' { Register-ToolkitScheduledTask -Action Unregister }
                    '3' { Register-ToolkitScheduledTask -Action RunNow }
                }
                Pause
            }
            '10' {
                Clear-Host
                $logPath = Join-Path $HOME "LaptopToolkit\Reports\toolkit-history.log"
                if (Test-Path $logPath) {
                    Get-Content $logPath -Tail 25
                } else {
                    Write-Host "No activity logs recorded yet." -ForegroundColor DarkGray
                }
                Pause
            }
        }
    } while ($sel -ne 'Q' -and $sel -ne 'q')
}
