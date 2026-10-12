function Get-WifiStatus {
    <#
    .SYNOPSIS
        Reports Wi-Fi connection quality and security, and optionally scans nearby networks for channel congestion.
    .DESCRIPTION
        Read-only. Wraps 'netsh wlan' (English output). It never requests saved passwords.
        Nearby scans can require Windows location access on recent Windows 11 builds; if the list is
        empty, check Settings > Privacy & security > Location.
    .PARAMETER ScanNearby
        Also list nearby access points and summarize channel usage.
    .PARAMETER PassThru
        Return the result object instead of printing it.
    #>
    [CmdletBinding()]
    param(
        [switch]$ScanNearby,
        [switch]$PassThru
    )

    if (-not (Get-Command netsh.exe -ErrorAction SilentlyContinue)) {
        Write-Host "netsh.exe not found. This cmdlet is Windows-only." -ForegroundColor Yellow
        return
    }

    $ifaceText = & netsh.exe wlan show interfaces 2>&1
    $interfaces = @(ConvertFrom-NetshWlanInterface -Text ($ifaceText | ForEach-Object { "$_" }))

    $nearby = @()
    $channelSummary = @()
    if ($ScanNearby) {
        $netText = & netsh.exe wlan show networks mode=bssid 2>&1
        $nearby = @(ConvertFrom-NetshWlanNetwork -Text ($netText | ForEach-Object { "$_" }))
        $channelSummary = @(
            $nearby | Where-Object { $_.Channel } |
                Group-Object Band, Channel |
                ForEach-Object {
                    [PSCustomObject]@{
                        Band         = $_.Group[0].Band
                        Channel      = $_.Group[0].Channel
                        AccessPoints = $_.Count
                        StrongestPct = ($_.Group | Measure-Object SignalPercent -Maximum).Maximum
                    }
                } | Sort-Object Band, Channel
        )
    }

    $findings = @()
    foreach ($i in ($interfaces | Where-Object { $_.State -eq "connected" })) {
        if ($i.SignalPercent -ne $null -and $i.SignalPercent -lt 40) {
            $findings += "Weak signal on '$($i.Ssid)' ($($i.SignalPercent)%). Move closer to the access point or reduce obstructions."
        }
        if ($i.SecurityRating -eq "Weak") {
            $findings += "'$($i.Ssid)' uses weak security ($($i.Authentication) / $($i.Cipher)). Prefer WPA2 or WPA3."
        }
        if ($i.Band -eq "2.4 GHz" -and $i.SignalPercent -ne $null -and $i.SignalPercent -ge 60) {
            $findings += "Connected on 2.4 GHz. If your router offers 5 GHz, it is usually faster and less congested."
        }
    }
    if ($ScanNearby -and $interfaces.Count -gt 0) {
        $busy = $channelSummary | Where-Object { $_.Band -eq "2.4 GHz" -and $_.AccessPoints -ge 4 }
        foreach ($b in $busy) {
            $findings += "2.4 GHz channel $($b.Channel) has $($b.AccessPoints) access points. Consider channel 1, 6, or 11 with the fewest neighbours."
        }
    }

    $result = [PSCustomObject]@{
        Interfaces     = $interfaces
        Nearby         = $nearby
        ChannelSummary = $channelSummary
        Findings       = $findings
    }
    Write-ToolkitLog "Wi-Fi status checked ($($interfaces.Count) interface(s), nearby scan: $([bool]$ScanNearby))" "INFO"

    if ($PassThru) { return $result }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                    WI-FI ANALYZER                          " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    if ($interfaces.Count -eq 0) {
        Write-Host "No Wi-Fi interface found, the WLAN service is stopped, or netsh output is not in English." -ForegroundColor Yellow
        return
    }
    foreach ($i in $interfaces) {
        $color = if ($i.State -eq "connected") { "Green" } else { "DarkGray" }
        Write-Host ("{0}: {1}" -f $i.Name, $i.State) -ForegroundColor $color
        if ($i.State -eq "connected") {
            Write-Host ("  SSID: {0}   Band: {1}   Channel: {2}   Radio: {3}" -f $i.Ssid, $i.Band, $i.Channel, $i.RadioType)
            Write-Host ("  Signal: {0}% ({1})   Rx/Tx: {2}/{3} Mbps" -f $i.SignalPercent, $i.SignalQuality, $i.RxMbps, $i.TxMbps)
            Write-Host ("  Security: {0} / {1}  [{2}]" -f $i.Authentication, $i.Cipher, $i.SecurityRating)
        }
    }
    if ($ScanNearby) {
        Write-Host "`n[Channel Usage]" -ForegroundColor Yellow
        if ($channelSummary.Count -gt 0) { $channelSummary | Format-Table -AutoSize }
        else { Write-Host "No nearby networks returned (location access may be off)." -ForegroundColor DarkGray }
    }
    if ($findings.Count -gt 0) {
        Write-Host "`n[Findings]" -ForegroundColor Yellow
        $findings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
}
