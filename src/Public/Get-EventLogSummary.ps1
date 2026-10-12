function Get-EventLogSummary {
    <#
    .SYNOPSIS
        Summarizes recurring critical, error, and warning events from the System and Application logs.
    .DESCRIPTION
        Read-only. Collects Critical/Error/Warning events for the last N days, groups them by
        log, source and event ID to surface what keeps repeating, and flags well-known stability
        problems (unexpected shutdowns, blue screens, disk and hardware errors, app crashes).
        The Security log is deliberately not read. Standard users can read System and Application.
    .PARAMETER Days
        How far back to look (1-90). Default 7.
    .PARAMETER LogName
        Logs to analyze. Default: System and Application.
    .PARAMETER Top
        How many recurring event groups to show. Default 10.
    .PARAMETER MaxEvents
        Cap per log to keep runs fast. If reached, the summary is marked as truncated.
    .PARAMETER PassThru
        Return the summary object instead of printing it.
    .EXAMPLE
        Get-EventLogSummary -Days 14 -Top 15
    #>
    [CmdletBinding()]
    param(
        [ValidateRange(1, 90)]
        [int]$Days = 7,
        [ValidateSet("System", "Application")]
        [string[]]$LogName = @("System", "Application"),
        [ValidateRange(1, 50)]
        [int]$Top = 10,
        [ValidateRange(100, 50000)]
        [int]$MaxEvents = 5000,
        [switch]$PassThru
    )

    $start = (Get-Date).AddDays(-$Days)
    $events = @()
    $truncated = $false
    $unreadable = @()

    foreach ($log in $LogName) {
        try {
            $found = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Level = 1, 2, 3; StartTime = $start } -MaxEvents $MaxEvents -ErrorAction Stop)
        } catch {
            if ($_.FullyQualifiedErrorId -like "NoMatchingEventsFound*") {
                $found = @()
            } else {
                $found = @()
                $unreadable += $log
                Write-ToolkitLog "Could not read '$log' log: $($_.Exception.Message)" "WARN"
            }
        }
        if ($found.Count -ge $MaxEvents) { $truncated = $true }
        $events += $found
    }

    $summary = ConvertTo-EventSummary -Events $events -Top $Top -Days $Days -Truncated $truncated
    Write-ToolkitLog ("Event log summary ({0}d): {1} events, attention={2}" -f $Days, $summary.TotalEvents, $summary.NeedsAttention) "INFO"

    if ($PassThru) { return $summary }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "           EVENT LOG ANALYZER (LAST $Days DAYS)             " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ("Critical: {0}   Errors: {1}   Warnings: {2}   (logs: {3})" -f $summary.Critical, $summary.Errors, $summary.Warnings, ($LogName -join ", "))
    if ($summary.Truncated) {
        Write-Host "Note: hit the $MaxEvents-event cap on at least one log; counts are a lower bound." -ForegroundColor Yellow
    }
    foreach ($u in $unreadable) {
        Write-Host "Could not read the $u log." -ForegroundColor Yellow
    }

    if ($summary.KnownIssues.Count -gt 0) {
        Write-Host "`n[Known Stability Patterns]" -ForegroundColor Yellow
        foreach ($k in $summary.KnownIssues) {
            $color = if ($k.Serious) { "Red" } else { "Yellow" }
            Write-Host ("  {0,4}x  {1}  (last: {2:g})" -f $k.Count, $k.Meaning, $k.LastSeen) -ForegroundColor $color
        }
    } else {
        Write-Host "`nNo known stability patterns found." -ForegroundColor Green
    }

    if ($summary.TopEvents.Count -gt 0) {
        Write-Host "`n[Most Frequent Recurring Events]" -ForegroundColor Yellow
        $summary.TopEvents | Format-Table Count, Level, Log, Source, EventId, LastSeen, Sample -AutoSize -Wrap
    } else {
        Write-Host "No critical, error, or warning events in this period." -ForegroundColor Green
    }
}
