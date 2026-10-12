function Find-DuplicateFile {
    <#
    .SYNOPSIS
        Finds duplicate files by content hash. Read-only: it never deletes or moves anything.
    .DESCRIPTION
        Groups files by size first and only hashes files that share a size, so scans stay fast.
        Does not follow junctions or symlinks. Files you cannot read are skipped and counted.
    .PARAMETER Path
        Folder to scan.
    .PARAMETER MinSizeMB
        Ignore files smaller than this. Defaults to duplicates.minSizeMB in config.json.
    .PARAMETER MaxFiles
        Safety cap on how many files are examined. Default 200000.
    .PARAMETER Top
        How many duplicate groups to print (largest waste first). Default 10.
    .PARAMETER PassThru
        Return the result object instead of printing it.
    .EXAMPLE
        Find-DuplicateFile -Path $HOME\Downloads -MinSizeMB 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
        [string]$Path,
        [ValidateRange(0, 100000)]
        [double]$MinSizeMB,
        [ValidateRange(100, 5000000)]
        [int]$MaxFiles = 200000,
        [ValidateRange(1, 200)]
        [int]$Top = 10,
        [switch]$PassThru
    )

    $cfg = Get-ToolkitConfig
    if (-not $PSBoundParameters.ContainsKey('MinSizeMB')) { $MinSizeMB = $cfg.Duplicates.minSizeMB }
    $minBytes = [long]($MinSizeMB * 1MB)
    $root = (Resolve-Path -LiteralPath $Path).ProviderPath

    $scanned = 0
    $capped = $false
    $bySize = @{}
    foreach ($f in (Get-FileTree -Root $root)) {
        if ($f.Length -lt $minBytes -or $f.Length -eq 0) { continue }
        $scanned++
        if ($scanned -gt $MaxFiles) { $capped = $true; break }
        $key = [string]$f.Length
        if (-not $bySize.ContainsKey($key)) { $bySize[$key] = New-Object System.Collections.Generic.List[object] }
        $bySize[$key].Add($f)
    }

    $unreadable = 0
    $groups = New-Object System.Collections.Generic.List[object]
    foreach ($key in $bySize.Keys) {
        $candidates = $bySize[$key]
        if ($candidates.Count -lt 2) { continue }
        $hashes = @{}
        foreach ($f in $candidates) {
            try {
                $h = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                if (-not $hashes.ContainsKey($h)) { $hashes[$h] = New-Object System.Collections.Generic.List[string] }
                $hashes[$h].Add($f.FullName)
            } catch { $unreadable++ }
        }
        foreach ($h in $hashes.Keys) {
            $files = $hashes[$h]
            if ($files.Count -lt 2) { continue }
            $size = [long]$key
            $groups.Add([PSCustomObject]@{
                Hash     = $h
                Copies   = $files.Count
                SizeMB   = [math]::Round($size / 1MB, 2)
                WastedMB = [math]::Round(($size * ($files.Count - 1)) / 1MB, 2)
                Files    = @($files | Sort-Object)
            })
        }
    }

    $sorted = @($groups | Sort-Object WastedMB -Descending)
    $wasted = ($sorted | Measure-Object WastedMB -Sum).Sum
    if (-not $wasted) { $wasted = 0 }
    $result = [PSCustomObject]@{
        Root            = $root
        FilesExamined   = [math]::Min($scanned, $MaxFiles)
        Capped          = $capped
        Unreadable      = $unreadable
        DuplicateGroups = $sorted.Count
        WastedMB        = [math]::Round($wasted, 2)
        Groups          = $sorted
    }
    Write-ToolkitLog "Duplicate scan of '$root': $($sorted.Count) groups, $($result.WastedMB) MB reclaimable" "INFO"

    if ($PassThru) { return $result }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                DUPLICATE FILE FINDER (READ-ONLY)           " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ("Scanned: {0}  (files >= {1} MB, {2} examined)" -f $root, $MinSizeMB, $result.FilesExamined)
    if ($capped) { Write-Host "Stopped at the $MaxFiles-file cap; results are partial." -ForegroundColor Yellow }
    if ($unreadable -gt 0) { Write-Host "$unreadable file(s) could not be read and were skipped." -ForegroundColor DarkGray }

    if ($sorted.Count -eq 0) {
        Write-Host "No duplicates found." -ForegroundColor Green
        return
    }
    Write-Host ("{0} duplicate group(s); about {1} MB could be reclaimed by keeping one copy of each." -f $sorted.Count, $result.WastedMB) -ForegroundColor Yellow
    $n = 0
    foreach ($g in ($sorted | Select-Object -First $Top)) {
        $n++
        Write-Host ("`n#{0}: {1} copies x {2} MB (wasted {3} MB)" -f $n, $g.Copies, $g.SizeMB, $g.WastedMB) -ForegroundColor Cyan
        $g.Files | ForEach-Object { Write-Host "   $_" }
    }
    Write-Host "`nNothing was changed. Review the lists and delete manually." -ForegroundColor DarkGray
}
