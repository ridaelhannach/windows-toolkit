function Get-ToolkitConfig {
    <#
    .SYNOPSIS
        Returns the effective toolkit settings (built-in defaults < shipped config.json < user override).
    .DESCRIPTION
        Precedence, lowest to highest:
          1. Safe defaults compiled into this function
          2. <module>\config.json (shipped with the toolkit)
          3. $HOME\LaptopToolkit\config.json (your overrides; survives re-installs)
        A missing or malformed file is skipped with a log entry, never a failure.
        Values are validated; anything out of range falls back to the default.
        The result is cached for the session. Use -Reload after editing a file.
    #>
    [CmdletBinding()]
    param([switch]$Reload)

    if ($script:ToolkitConfigCache -and -not $Reload) { return $script:ToolkitConfigCache }

    $cfg = @{
        thresholds = @{
            cpuWarningPercent     = 80
            cpuCriticalPercent    = 90
            ramWarningPercent     = 75
            ramCriticalPercent    = 88
            diskFreeWarningPercent = 15
        }
        maintenance = @{
            tempRetentionDays = 2
            emptyRecycleBin   = $false   # irreversible, so off unless you opt in
            scanWindowsTemp   = $true
        }
        developerTools = @("git", "node", "npm", "python", "pip", "docker", "code", "cargo", "go", "dotnet")
        network = @{
            dnsProbeTargets            = @("1.1.1.1", "google.com")
            maxListeningPortsDisplayed = 20
        }
        git = @{
            scanRoots = @()      # empty = auto-detect common project folders
            maxDepth  = 3
        }
        duplicates = @{
            minSizeMB = 1
        }
    }

    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $files = @(
        (Join-Path $moduleRoot "config.json"),
        (Join-Path $HOME "LaptopToolkit\config.json")
    )

    foreach ($file in $files) {
        if (-not (Test-Path -LiteralPath $file)) { continue }
        try {
            $json = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
            Write-ToolkitLog "Ignoring unreadable config '$file': $($_.Exception.Message)" "WARN"
            continue
        }

        foreach ($section in @("thresholds", "maintenance", "network", "git", "duplicates")) {
            if ($json.PSObject.Properties[$section]) {
                foreach ($prop in $json.$section.PSObject.Properties) {
                    if ($cfg[$section].ContainsKey($prop.Name)) { $cfg[$section][$prop.Name] = $prop.Value }
                }
            }
        }
        if ($json.PSObject.Properties["developerTools"] -and $json.developerTools) {
            $cfg.developerTools = @($json.developerTools | ForEach-Object { [string]$_ })
        }
    }

    # Validation: coerce and range-check, fall back to defaults on bad values
    $defaults = @{
        cpuWarningPercent = 80; cpuCriticalPercent = 90; ramWarningPercent = 75
        ramCriticalPercent = 88; diskFreeWarningPercent = 15
    }
    foreach ($k in $defaults.Keys) {
        $v = $cfg.thresholds[$k] -as [double]
        if ($null -eq $v -or $v -lt 1 -or $v -gt 100) {
            Write-ToolkitLog "Invalid threshold '$k'; using default $($defaults[$k])" "WARN"
            $v = $defaults[$k]
        }
        $cfg.thresholds[$k] = $v
    }
    $days = $cfg.maintenance.tempRetentionDays -as [int]
    if ($null -eq $days -or $days -lt 0 -or $days -gt 3650) {
        Write-ToolkitLog "Invalid tempRetentionDays; using default 2" "WARN"
        $days = 2
    }
    $cfg.maintenance.tempRetentionDays = $days
    $cfg.maintenance.emptyRecycleBin = [bool]$cfg.maintenance.emptyRecycleBin
    $cfg.maintenance.scanWindowsTemp = [bool]$cfg.maintenance.scanWindowsTemp

    $maxPorts = $cfg.network.maxListeningPortsDisplayed -as [int]
    if ($null -eq $maxPorts -or $maxPorts -lt 1 -or $maxPorts -gt 500) { $maxPorts = 20 }
    $cfg.network.maxListeningPortsDisplayed = $maxPorts
    $cfg.network.dnsProbeTargets = @($cfg.network.dnsProbeTargets | ForEach-Object { [string]$_ } | Where-Object { $_ })
    if ($cfg.network.dnsProbeTargets.Count -eq 0) { $cfg.network.dnsProbeTargets = @("1.1.1.1", "google.com") }
    $cfg.developerTools = @($cfg.developerTools | Where-Object { $_ -match '^[A-Za-z0-9._-]+$' })

    $depth = $cfg.git.maxDepth -as [int]
    if ($null -eq $depth -or $depth -lt 1 -or $depth -gt 6) { $depth = 3 }
    $cfg.git.maxDepth = $depth
    $cfg.git.scanRoots = @($cfg.git.scanRoots | ForEach-Object { [string]$_ } | Where-Object { $_ })

    $minMB = $cfg.duplicates.minSizeMB -as [double]
    if ($null -eq $minMB -or $minMB -lt 0 -or $minMB -gt 100000) { $minMB = 1 }
    $cfg.duplicates.minSizeMB = $minMB

    $script:ToolkitConfigCache = [PSCustomObject]@{
        Thresholds     = [PSCustomObject]$cfg.thresholds
        Maintenance    = [PSCustomObject]$cfg.maintenance
        DeveloperTools = $cfg.developerTools
        Network        = [PSCustomObject]$cfg.network
        Git            = [PSCustomObject]$cfg.git
        Duplicates     = [PSCustomObject]$cfg.duplicates
    }
    return $script:ToolkitConfigCache
}
