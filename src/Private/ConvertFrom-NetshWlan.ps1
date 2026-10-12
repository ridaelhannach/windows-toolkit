function Get-WifiBandFromChannel {
    param([int]$Channel)
    if ($Channel -ge 1 -and $Channel -le 14) { return "2.4 GHz" }
    if ($Channel -ge 32) { return "5 GHz" }
    return "Unknown"
}

function Get-WifiSecurityRating {
    <# Weak: open, WEP, WPA1, or TKIP. OK: WPA2. Strong: WPA3. #>
    param([string]$Authentication, [string]$Cipher)
    if (-not $Authentication) { return "Unknown" }
    if ($Authentication -match "^Open" -or $Authentication -match "WEP") { return "Weak" }
    if ($Cipher -match "TKIP|WEP") { return "Weak" }
    if ($Authentication -match "^WPA-") { return "Weak" }        # WPA1
    if ($Authentication -match "WPA3") { return "Strong" }
    if ($Authentication -match "WPA2") { return "OK" }
    return "Unknown"
}

function Get-WifiSignalQuality {
    param($Percent)
    if ($null -eq $Percent) { return "Unknown" }
    if ($Percent -ge 80) { return "Excellent" }
    if ($Percent -ge 60) { return "Good" }
    if ($Percent -ge 40) { return "Fair" }
    return "Poor"
}

function ConvertFrom-NetshWlanInterface {
    <#
    .SYNOPSIS
        Parses 'netsh wlan show interfaces' text (English output) into objects. Pure function.
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][string[]]$Text)

    $lines = @(($Text -join "`n") -split "`r?`n")
    $current = $null
    $items = @()

    foreach ($line in $lines) {
        if ($line -notmatch '^\s*([^:]+?)\s*:\s*(.*)$') { continue }
        $key = $Matches[1].Trim()
        $val = $Matches[2].Trim()

        if ($key -eq "Name") {
            if ($current) { $items += $current }
            $current = @{ Name = $val }
            continue
        }
        if (-not $current) { continue }
        switch ($key) {
            "State"                { $current.State = $val }
            "SSID"                 { $current.Ssid = $val }
            "AP BSSID"             { $current.Bssid = $val }
            "BSSID"                { if (-not $current.Bssid) { $current.Bssid = $val } }
            "Radio type"           { $current.RadioType = $val }
            "Band"                 { $current.Band = $val }
            "Channel"              { $current.Channel = ($val -as [int]) }
            "Authentication"       { $current.Authentication = $val }
            "Cipher"               { $current.Cipher = $val }
            "Receive rate (Mbps)"  { $current.RxMbps = ($val -as [double]) }
            "Transmit rate (Mbps)" { $current.TxMbps = ($val -as [double]) }
            "Signal"               { $current.SignalPercent = (($val -replace '%', '') -as [int]) }
        }
    }
    if ($current) { $items += $current }

    foreach ($i in $items) {
        if (-not $i.State) { continue }
        $band = $i.Band
        if (-not $band -and $i.Channel) { $band = Get-WifiBandFromChannel $i.Channel }
        [PSCustomObject]@{
            Name           = $i.Name
            State          = $i.State
            Ssid           = $i.Ssid
            Bssid          = $i.Bssid
            RadioType      = $i.RadioType
            Band           = $band
            Channel        = $i.Channel
            Authentication = $i.Authentication
            Cipher         = $i.Cipher
            SignalPercent  = $i.SignalPercent
            SignalQuality  = Get-WifiSignalQuality $i.SignalPercent
            RxMbps         = $i.RxMbps
            TxMbps         = $i.TxMbps
            SecurityRating = Get-WifiSecurityRating $i.Authentication $i.Cipher
        }
    }
}

function ConvertFrom-NetshWlanNetwork {
    <#
    .SYNOPSIS
        Parses 'netsh wlan show networks mode=bssid' text into one object per access point. Pure function.
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][string[]]$Text)

    $lines = @(($Text -join "`n") -split "`r?`n")
    $ssid = $null; $auth = $null; $enc = $null; $bss = $null
    $rows = New-Object System.Collections.Generic.List[object]

    $flush = {
        if ($bss) {
            $band = $bss.Band
            if (-not $band -and $bss.Channel) { $band = Get-WifiBandFromChannel $bss.Channel }
            $name = if ($ssid) { $ssid } else { "(hidden)" }
            $rows.Add([PSCustomObject]@{
                Ssid           = $name
                Bssid          = $bss.Bssid
                SignalPercent  = $bss.Signal
                Channel        = $bss.Channel
                Band           = $band
                RadioType      = $bss.Radio
                Authentication = $auth
                SecurityRating = Get-WifiSecurityRating $auth $enc
            })
        }
    }

    foreach ($line in $lines) {
        if ($line -match '^SSID\s+\d+\s*:\s*(.*)$') {
            & $flush; $bss = $null
            $ssid = $Matches[1].Trim(); $auth = $null; $enc = $null
        } elseif ($line -match '^\s*BSSID\s+\d+\s*:\s*(.*)$') {
            & $flush
            $bss = @{ Bssid = $Matches[1].Trim() }
        } elseif ($line -match '^\s*([^:]+?)\s*:\s*(.*)$') {
            $k = $Matches[1].Trim(); $v = $Matches[2].Trim()
            if ($bss) {
                switch ($k) {
                    "Signal"     { $bss.Signal = (($v -replace '%', '') -as [int]) }
                    "Radio type" { $bss.Radio = $v }
                    "Band"       { $bss.Band = $v }
                    "Channel"    { $bss.Channel = ($v -as [int]) }
                }
            } elseif ($ssid -ne $null) {
                switch ($k) {
                    "Authentication" { $auth = $v }
                    "Encryption"     { $enc = $v }
                }
            }
        }
    }
    & $flush
    $rows.ToArray()
}
