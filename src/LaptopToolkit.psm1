# LaptopToolkit.psm1 - Module Root Loader

$PublicDir  = Join-Path $PSScriptRoot "Public"
$PrivateDir = Join-Path $PSScriptRoot "Private"

# 1. Load Private Helpers
if (Test-Path $PrivateDir) {
    Get-ChildItem -Path $PrivateDir -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

# 2. Load Public Cmdlets
if (Test-Path $PublicDir) {
    Get-ChildItem -Path $PublicDir -Filter "*.ps1" | ForEach-Object {
        . $_.FullName
    }
}

Set-Alias -Name toolkit -Value Start-ToolkitDashboard

# 3. Export Specific Cmdlets
Export-ModuleMember -Function @(
    "Get-LaptopHealth",
    "Test-SecurityStatus",
    "Test-NetworkDiagnostics",
    "Test-DeveloperEnvironment",
    "Invoke-SafeDiskCleanup",
    "Get-StartupPrograms",
    "Get-EventLogSummary",
    "Get-WifiStatus",
    "Find-DuplicateFile",
    "Get-SoftwareUpdate",
    "Update-SoftwarePackage",
    "Get-GitProjectStatus",
    "New-HealthReport",
    "New-BatteryReport",
    "Register-ToolkitScheduledTask",
    "Start-ToolkitDashboard"
) -Alias @("toolkit")

