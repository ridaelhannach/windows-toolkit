function ConvertTo-EventSummary {
    <#
    .SYNOPSIS
        Pure aggregation of event records into a summary (no system access, so it is unit-testable).
    .DESCRIPTION
        Accepts objects with ProviderName, Id, Level, LogName, TimeCreated and Message
        (Get-WinEvent output or test doubles) and returns counts, the most frequent
        recurring events, and matches against well-known stability problems.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [object[]]$Events = @(),
        [ValidateRange(1, 50)]
        [int]$Top = 10,
        [int]$Days = 7,
        [bool]$Truncated = $false
    )

    $known = @(
        @{ Provider = "Microsoft-Windows-Kernel-Power";            Ids = @(41);                 Meaning = "Unexpected shutdown or reboot (power loss, crash, or hard reset)" },
        @{ Provider = "EventLog";                                  Ids = @(6008);               Meaning = "Previous shutdown was unexpected" },
        @{ Provider = "Microsoft-Windows-WER-SystemErrorReporting"; Ids = @(1001);              Meaning = "Blue screen (bugcheck) recorded" },
        @{ Provider = "Application Error";                         Ids = @(1000);               Meaning = "Application crash" },
        @{ Provider = "Application Hang";                          Ids = @(1002);               Meaning = "Application stopped responding" },
        @{ Provider = "disk";                                      Ids = @(7, 11, 51, 153);     Meaning = "Disk I/O errors or bad blocks: back up data and check drive health" },
        @{ Provider = "Microsoft-Windows-Ntfs";                    Ids = @(55, 137, 140);       Meaning = "File system corruption or volume problems" },
        @{ Provider = "Microsoft-Windows-WHEA-Logger";             Ids = @(17, 18, 19, 20);     Meaning = "Hardware error reported (CPU, memory, or PCIe)" },
        @{ Provider = "Display";                                   Ids = @(4101);               Meaning = "Display driver stopped responding and recovered" }
    )
    # Pattern groups that suggest hardware or stability trouble rather than a noisy app
    $serious = @("Microsoft-Windows-Kernel-Power", "EventLog", "Microsoft-Windows-WER-SystemErrorReporting",
                 "disk", "Microsoft-Windows-Ntfs", "Microsoft-Windows-WHEA-Logger")

    $all = @($Events | Where-Object { $_ })

    $topEvents = @(
        $all | Group-Object { "{0}|{1}|{2}" -f $_.LogName, $_.ProviderName, $_.Id } |
            Sort-Object Count -Descending |
            Select-Object -First $Top |
            ForEach-Object {
                $g = $_.Group
                $sorted = $g | Sort-Object TimeCreated
                $worst = ($g | Measure-Object -Property Level -Minimum).Minimum
                $levelName = switch ([int]$worst) { 1 { "Critical" } 2 { "Error" } default { "Warning" } }
                $msg = ""
                foreach ($candidate in $g) {
                    if ($candidate.Message) { $msg = ($candidate.Message -split "`r?`n")[0]; break }
                }
                if ($msg.Length -gt 110) { $msg = $msg.Substring(0, 107) + "..." }
                [PSCustomObject]@{
                    Count     = $_.Count
                    Level     = $levelName
                    Log       = $g[0].LogName
                    Source    = $g[0].ProviderName
                    EventId   = $g[0].Id
                    FirstSeen = $sorted[0].TimeCreated
                    LastSeen  = $sorted[-1].TimeCreated
                    Sample    = $msg
                }
            }
    )

    $knownIssues = @(
        foreach ($k in $known) {
            $hits = @($all | Where-Object { $_.ProviderName -eq $k.Provider -and $_.Id -in $k.Ids })
            if ($hits.Count -gt 0) {
                [PSCustomObject]@{
                    Count    = $hits.Count
                    Source   = $k.Provider
                    EventIds = ($k.Ids -join ",")
                    Meaning  = $k.Meaning
                    LastSeen = ($hits | Sort-Object TimeCreated | Select-Object -Last 1).TimeCreated
                    Serious  = ($k.Provider -in $serious)
                }
            }
        }
    )

    [PSCustomObject]@{
        Days           = $Days
        TotalEvents    = $all.Count
        Critical       = @($all | Where-Object { $_.Level -eq 1 }).Count
        Errors         = @($all | Where-Object { $_.Level -eq 2 }).Count
        Warnings       = @($all | Where-Object { $_.Level -eq 3 }).Count
        Truncated      = $Truncated
        TopEvents      = $topEvents
        KnownIssues    = $knownIssues
        NeedsAttention = (@($knownIssues | Where-Object { $_.Serious }).Count -gt 0)
    }
}
