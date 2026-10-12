function Test-DeveloperEnvironment {
    <#
    .SYNOPSIS
        Audits installed developer CLI tools, runtimes, and package managers.
    .DESCRIPTION
        Checks whether standard developer binaries (git, node, python, docker, etc.)
        are discoverable on PATH and reports version strings.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Tools,
        [switch]$PassThru
    )

    if (-not $Tools) { $Tools = (Get-ToolkitConfig).DeveloperTools }
    $results = @()
    foreach ($t in $Tools) {
        $cmd = Get-Command $t -ErrorAction SilentlyContinue
        if ($cmd) {
            $verArg = if ($t -eq "go") { "version" } else { "--version" }
            $rawVer = try { & $cmd.Source $verArg 2>&1 | Select-Object -First 1 } catch { "Found" }
            if ($null -eq $rawVer) { $rawVer = "Found" }
            $results += [PSCustomObject]@{
                Tool      = $t
                Installed = $true
                Version   = $rawVer.ToString().Trim()
                Path      = $cmd.Source
            }
        } else {
            $results += [PSCustomObject]@{
                Tool      = $t
                Installed = $false
                Version   = "Not Found"
                Path      = $null
            }
        }
    }

    if ($PassThru) {
        return $results
    }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              DEVELOPER TOOLCHAIN & ENVIRONMENT             " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan

    foreach ($r in $results) {
        if ($r.Installed) {
            Write-Host ("  {0,-12} : Found ({1})" -f $r.Tool, $r.Version) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-12} : Not Installed" -f $r.Tool) -ForegroundColor DarkGray
        }
    }
}
