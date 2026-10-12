function ConvertFrom-WingetUpgrade {
    <#
    .SYNOPSIS
        Parses the table printed by 'winget upgrade' into objects. Pure function.
    .DESCRIPTION
        Column positions come from the header row, so it tolerates varying widths. English headers only.
        Names containing wide (e.g. CJK) characters can shift columns in winget's own output; such rows
        may be misread.
    #>
    [CmdletBinding()]
    param([AllowEmptyString()][string[]]$Text)

    # winget redraws a spinner using carriage returns; treat each piece as its own line.
    $lines = @(($Text -join "`n") -split "[\r\n]+" | ForEach-Object { $_.TrimEnd() })

    $hdr = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^Name\s+Id\s+Version\s+Available') { $hdr = $i; break }
    }
    if ($hdr -lt 0) { return @() }

    $h = $lines[$hdr]
    $idIdx    = $h.IndexOf("Id")
    $verIdx   = $h.IndexOf("Version")
    $availIdx = $h.IndexOf("Available")
    $srcIdx   = $h.IndexOf("Source")

    $start = $hdr + 1
    if ($start -lt $lines.Count -and $lines[$start] -match '^-{5,}') { $start++ }

    for ($i = $start; $i -lt $lines.Count; $i++) {
        $row = $lines[$i]
        if (-not $row.Trim()) { break }
        if ($row -match '^\d+\s+upgrades?\s+available' -or $row -match '^The following packages') { break }
        if ($row.Length -le $availIdx) { continue }

        $endAvail = if ($srcIdx -gt 0 -and $row.Length -gt $srcIdx) { $srcIdx } else { $row.Length }
        $source = if ($srcIdx -gt 0 -and $row.Length -gt $srcIdx) { $row.Substring($srcIdx).Trim() } else { "" }
        [PSCustomObject]@{
            Name      = $row.Substring(0, $idIdx).Trim()
            Id        = $row.Substring($idIdx, $verIdx - $idIdx).Trim()
            Version   = $row.Substring($verIdx, $availIdx - $verIdx).Trim()
            Available = $row.Substring($availIdx, $endAvail - $availIdx).Trim()
            Source    = $source
        }
    }
}
