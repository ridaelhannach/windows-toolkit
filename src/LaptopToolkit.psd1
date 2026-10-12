@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'LaptopToolkit.psm1'

    # Version number of this module.
    ModuleVersion = '1.0.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')

    # ID used to uniquely identify this module
    GUID = '7815cfb2-c0cb-464a-92b5-f483c076595a'

    # Author of this module
    Author = 'Rida El Hannach'

    # Company or vendor of this module
    CompanyName = 'Community'

    # Copyright statement for this module
    Copyright = '(c) 2026 Rida El Hannach. All rights reserved.'

    # Description of the functionality provided by this module
    Description = 'A modular, safety-first IT automation toolkit for Windows workstations and laptops. Provides system diagnostics, security audits, network telemetry, safe disk cleanup, reporting, and maintenance scheduling.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'Get-LaptopHealth',
        'Test-SecurityStatus',
        'Test-NetworkDiagnostics',
        'Test-DeveloperEnvironment',
        'Invoke-SafeDiskCleanup',
        'Get-StartupPrograms',
        'Get-EventLogSummary',
        'Get-WifiStatus',
        'Find-DuplicateFile',
        'Get-SoftwareUpdate',
        'Update-SoftwarePackage',
        'Get-GitProjectStatus',
        'New-HealthReport',
        'New-BatteryReport',
        'Register-ToolkitScheduledTask',
        'Start-ToolkitDashboard'
    )

    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @('toolkit')

    # Private data to pass to the module specified in RootModule
    PrivateData = @{
        PSData = @{
            Tags = @('ITOps', 'SysAdmin', 'HealthCheck', 'Maintenance', 'Diagnostics', 'Security', 'Cleanup', 'Windows')
            LicenseUri = 'https://opensource.org/licenses/MIT'
            ProjectUri = 'https://github.com/ridaelhannach/windows-toolkit'
        }
    }
}
