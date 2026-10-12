function New-BatteryReport {
    <#
    .SYNOPSIS
        Generates Windows Battery Health & Degradation report.
    .DESCRIPTION
        Invokes powercfg /batteryreport to generate capacity and usage history.
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [switch]$NoOpen
    )

    $reportsDir = Join-Path $HOME "LaptopToolkit\Reports"
    if (-not (Test-Path $reportsDir)) { New-Item -ItemType Directory -Path $reportsDir -Force | Out-Null }

    if (-not $OutputPath) {
        $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
        $OutputPath = Join-Path $reportsDir "battery-report_$timestamp.html"
    }

    Write-Host "Generating battery report..." -ForegroundColor Cyan
    powercfg /batteryreport /output $OutputPath | Out-Null

    if (Test-Path $OutputPath) {
        Write-Host "Battery report generated: $OutputPath" -ForegroundColor Green
        Write-ToolkitLog "Generated battery report: $OutputPath" "INFO"
        if (-not $NoOpen) {
            Start-Process $OutputPath
        }
    } else {
        Write-Host "Unable to generate battery report. (Device may not have a battery)." -ForegroundColor DarkGray
    }
}
