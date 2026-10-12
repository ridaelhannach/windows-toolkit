function Update-SoftwarePackage {
    <#
    .SYNOPSIS
        Upgrades specific WinGet packages by exact ID, with a confirmation prompt for each.
    .DESCRIPTION
        Deliberately has no "upgrade everything" mode. Package IDs are validated before they are passed
        to winget. Supports -WhatIf. Some upgrades may show a UAC prompt or close the running app.
    .EXAMPLE
        Get-SoftwareUpdate -PassThru | Where-Object Name -like "*Git*" | Update-SoftwarePackage
    #>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._+-]*$')]
        [string[]]$Id
    )

    begin {
        $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $winget) { throw "WinGet (App Installer) was not found." }
    }
    process {
        foreach ($pkg in $Id) {
            if (-not $PSCmdlet.ShouldProcess($pkg, "winget upgrade")) { continue }
            & $winget.Source upgrade --id $pkg --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
            $code = $LASTEXITCODE
            if ($code -eq 0) {
                Write-Host "Updated $pkg." -ForegroundColor Green
                Write-ToolkitLog "Upgraded package $pkg via winget" "INFO"
            } else {
                Write-Host "winget exited with code $code for $pkg." -ForegroundColor Yellow
                Write-ToolkitLog "winget upgrade $pkg exited with code $code" "WARN"
            }
        }
    }
}
