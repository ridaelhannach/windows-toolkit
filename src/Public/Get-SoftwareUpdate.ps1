function Get-SoftwareUpdate {
    <#
    .SYNOPSIS
        Lists installed applications that have a newer version available through WinGet. Read-only.
    .PARAMETER IncludeUnknown
        Also list packages whose installed version WinGet cannot determine.
    .PARAMETER PassThru
        Return the package objects (Name, Id, Version, Available, Source), e.g. to pipe into Update-SoftwarePackage.
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeUnknown,
        [switch]$PassThru
    )

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        Write-Host "WinGet (App Installer) was not found. Install it from the Microsoft Store." -ForegroundColor Yellow
        if ($PassThru) { return @() }
        return
    }

    $wingetArgs = @("upgrade", "--accept-source-agreements", "--disable-interactivity")
    if ($IncludeUnknown) { $wingetArgs += "--include-unknown" }

    $prevEncoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = & $winget.Source @wingetArgs 2>&1 | ForEach-Object { "$_" }
    } finally {
        [Console]::OutputEncoding = $prevEncoding
    }

    $packages = @(ConvertFrom-WingetUpgrade -Text $raw)
    Write-ToolkitLog "WinGet check: $($packages.Count) update(s) available" "INFO"

    if ($PassThru) { return $packages }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                SOFTWARE UPDATE CHECK (WINGET)              " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    if ($packages.Count -eq 0) {
        Write-Host "No updates reported (or WinGet output was not in English)." -ForegroundColor Green
        return
    }
    Write-Host "$($packages.Count) update(s) available:" -ForegroundColor Yellow
    $packages | Format-Table Name, Id, Version, Available, Source -AutoSize
    Write-Host "Update one with: Update-SoftwarePackage -Id <Id>   (asks for confirmation; supports -WhatIf)" -ForegroundColor DarkGray
}
