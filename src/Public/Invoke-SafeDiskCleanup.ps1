function Invoke-SafeDiskCleanup {
    <#
    .SYNOPSIS
        Safely identifies and purges temporary files with safety guardrails.
    .DESCRIPTION
        Discovery-first: always reports what is reclaimable. Nothing is deleted unless you pass
        -Clean or confirm the prompt. Supports -WhatIf. Skips junctions/symlinks so deletion can
        never escape the temp folders, and skips locked files.
        The Recycle Bin is only emptied when -EmptyRecycleBin is passed explicitly.
    .PARAMETER Clean
        Executes deletion without the interactive Y/N prompt.
    .PARAMETER DaysOld
        Minimum age of files to clean in days. Defaults to maintenance.tempRetentionDays in config.json.
    .PARAMETER EmptyRecycleBin
        Also empties the Recycle Bin (irreversible). Never implied by -Clean; only happens when this
        switch is passed or maintenance.emptyRecycleBin is set to true in your own config.
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [switch]$Clean,
        [ValidateRange(0, 3650)]
        [int]$DaysOld,
        [switch]$EmptyRecycleBin
    )

    $cfg = Get-ToolkitConfig
    if (-not $PSBoundParameters.ContainsKey('DaysOld')) { $DaysOld = $cfg.Maintenance.tempRetentionDays }
    $emptyBin = $EmptyRecycleBin.IsPresent -or $cfg.Maintenance.emptyRecycleBin

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             SMART DISK CLEANER (DISCOVERY & PURGE)         " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    $targets = @(
        @{ Name = "User Temp"; Path = "$env:TEMP" }
    )

    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if ($isAdmin -and $cfg.Maintenance.scanWindowsTemp) {
        $targets += @{ Name = "Windows System Temp"; Path = (Join-Path $env:SystemRoot "Temp") }
    } elseif (-not $isAdmin -and $cfg.Maintenance.scanWindowsTemp) {
        Write-Host "[Note] Run as Administrator to include the Windows Temp folder." -ForegroundColor DarkGray
    }

    $cutoffDate = (Get-Date).AddDays(-$DaysOld)

    # Files only; anything reached through a junction/symlink (ReparsePoint) is excluded.
    function Get-CleanupCandidate {
        param([string]$Path, [datetime]$Cutoff)
        Get-ChildItem -Path $Path -File -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.LastWriteTime -lt $Cutoff -and
                -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -and
                -not (Test-ReparseAncestor -File $_ -Root $Path)
            }
    }

    function Test-ReparseAncestor {
        param($File, [string]$Root)
        $dir = $File.Directory
        $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
        while ($dir -and $dir.FullName.TrimEnd('\') -ne $rootFull) {
            if ($dir.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { return $true }
            $dir = $dir.Parent
        }
        return $false
    }

    $summary = @()
    $candidates = @{}
    $totalCleanableBytes = 0

    foreach ($target in $targets) {
        if (Test-Path $target.Path) {
            Assert-SafePath $target.Path
            $files = @(Get-CleanupCandidate -Path $target.Path -Cutoff $cutoffDate)
            $candidates[$target.Name] = $files
            $bytes = ($files | Measure-Object -Property Length -Sum).Sum
            if (-not $bytes) { $bytes = 0 }
            $totalCleanableBytes += $bytes
            $summary += [PSCustomObject]@{
                Target    = $target.Name
                Path      = $target.Path
                FileCount = $files.Count
                SizeMB    = [math]::Round($bytes / 1MB, 2)
            }
        }
    }

    Write-Host "`n[Discovery Analysis (Files older than $DaysOld days)]" -ForegroundColor Yellow
    $summary | Format-Table -AutoSize
    Write-Host ("Total Reclaimable Space: {0} MB" -f [math]::Round($totalCleanableBytes / 1MB, 2)) -ForegroundColor Cyan

    # -WhatIf never prompts and never deletes.
    if ($WhatIfPreference) {
        Write-Host "WhatIf: no files were deleted." -ForegroundColor DarkGray
        return
    }

    if (-not $Clean) {
        $confirm = Read-Host "`nDo you want to safely purge these temporary files now? (Y/N)"
        if ($confirm -ne 'Y' -and $confirm -ne 'y') {
            Write-Host "Clean cancelled. Discovery mode completed without changes." -ForegroundColor DarkGray
            return
        }
    }

    $deletedCount = 0
    $skippedCount = 0
    $reclaimedBytes = 0

    # One ShouldProcess decision per target folder, not per file.
    foreach ($target in $targets) {
        if (-not $candidates.ContainsKey($target.Name)) { continue }
        if (-not $PSCmdlet.ShouldProcess($target.Path, "Delete temp files older than $DaysOld days")) { continue }

        Write-Host ("Cleaning {0}..." -f $target.Name) -ForegroundColor Yellow
        foreach ($f in $candidates[$target.Name]) {
            try {
                $sz = $f.Length
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $deletedCount++
                $reclaimedBytes += $sz
            } catch {
                $skippedCount++   # locked, in use, or access denied
            }
        }
    }

    if ($emptyBin) {
        if ($PSCmdlet.ShouldProcess("Recycle Bin", "Permanently empty")) {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Host "Recycle Bin purged." -ForegroundColor Green
        }
    }

    $actualReclaimedMB = [math]::Round($reclaimedBytes / 1MB, 2)
    Write-Host "`n[Cleanup Results]" -ForegroundColor Green
    Write-Host ("Deleted Files: {0} ({1} MB)" -f $deletedCount, $actualReclaimedMB)
    Write-Host ("Skipped Files (In-use/Locked): {0}" -f $skippedCount) -ForegroundColor DarkGray
    Write-ToolkitLog "Cleaned $deletedCount files ($actualReclaimedMB MB). Skipped $skippedCount locked files." "INFO"
}
