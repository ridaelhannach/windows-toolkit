# LaptopToolkit 💻⚡

[![CI](https://github.com/ridaelhannach/windows-toolkit/actions/workflows/ci.yml/badge.svg)](https://github.com/ridaelhannach/windows-toolkit/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![PowerShell: 5.1 & 7+](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows%2010%20%7C%2011-lightgrey.svg)](https://microsoft.com/windows)

A modular, safety-first IT automation toolkit and management console built for Windows workstations and laptops. It consolidates hardware telemetry, security audits, network diagnostics, developer environment checks, safe disk maintenance, responsive HTML reporting, and task scheduling into a single native PowerShell module.

No heavy dependencies. No third-party bloatware. Native PowerShell.

---

## Features

| Category | Cmdlet | Description |
| :--- | :--- | :--- |
| **Health** | `Get-LaptopHealth` | Real-time CPU, RAM, uptime, battery telemetry, and disk volume health. |
| **Security** | `Test-SecurityStatus` | Audits Microsoft Defender, active Windows Firewall profiles, and BitLocker. |
| **Network** | `Test-NetworkDiagnostics` | Tests adapters, gateway ping, DNS resolution, public IP, and listening TCP ports. |
| **Developer** | `Test-DeveloperEnvironment` | Checks presence and versions of `git`, `node`, `npm`, `python`, `docker`, `code`, etc. |
| **Maintenance** | `Invoke-SafeDiskCleanup` | Discovery-first temporary file and cache cleaner with strict path guards. |
| **Events** | `Get-EventLogSummary` | Read-only summary of recurring critical/error/warning events (System and Application logs) and known crash, disk, and hardware patterns. |
| **Network** | `Get-WifiStatus` | Wi-Fi signal quality, security rating, and (with `-ScanNearby`) channel congestion. |
| **Storage** | `Find-DuplicateFile` | Read-only duplicate finder using size grouping plus SHA-256. Never deletes. |
| **Software** | `Get-SoftwareUpdate` / `Update-SoftwarePackage` | Lists WinGet updates; upgrades specific packages by ID with confirmation (no "upgrade all"). |
| **Developer** | `Get-GitProjectStatus` | Scans project folders for uncommitted work, unpushed commits, stashes. Hostile-repo safe. |
| **Startup** | `Get-StartupPrograms` | Inspects registry run keys (`HKCU` and `HKLM`) for boot applications. |
| **Reporting** | `New-HealthReport` | Generates a responsive, standalone HTML health dashboard. |
| **Reporting** | `New-BatteryReport` | Triggers Windows' detailed battery capacity and degradation report. |
| **Scheduling** | `Register-ToolkitScheduledTask`| Manages the weekly automated background maintenance task in Task Scheduler. |
| **Dashboard** | `Start-ToolkitDashboard` | Launches the interactive console menu (alias: `toolkit`). |

---

## Quick Installation

Installing only copies the module into your user module folder. The execution policy, desktop
shortcut, and profile launcher are **opt-in** (you are asked, default No, or pass a switch).

### Option 1: Clone and Setup (recommended)
```powershell
git clone https://github.com/ridaelhannach/windows-toolkit.git
cd windows-toolkit
.\QuickSetup.ps1                 # add -AddToProfile -CreateShortcut to opt in without prompts
```

### Option 2: One-Line Installer
Downloads the moving `main` branch, so review the script first. Run in any PowerShell window:
```powershell
irm https://raw.githubusercontent.com/ridaelhannach/windows-toolkit/main/QuickSetup.ps1 | iex
```
For a reproducible install, pin a release tag and verify its hash:
```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/ridaelhannach/windows-toolkit/main/QuickSetup.ps1))) -Ref v1.0.0 -ExpectedSha256 <hash>
```

### Using it
```powershell
Import-Module LaptopToolkit
Start-ToolkitDashboard            # or the alias: toolkit
```
If you chose `-AddToProfile`, just type `toolkit` in any new terminal. If you chose `-CreateShortcut`,
use the **Laptop Toolkit** desktop icon.

### Uninstall
```powershell
.\QuickSetup.ps1 -Uninstall      # removes the module, shortcut, profile entry, and scheduled task
```
Logs and reports in `~\LaptopToolkit` are kept.

---

## Standalone Cmdlet Usage

Because LaptopToolkit is a native PowerShell module, you can use individual commands in your scripts, terminal sessions, or CI/CD pipelines:

```powershell
# Get structured health metrics as an object
$health = Get-LaptopHealth -PassThru
$health.RamUsedPct

# Run safe cleanup in Discovery Mode (analyzes without deleting)
Invoke-SafeDiskCleanup

# Execute cleanup for files older than 3 days and empty Recycle Bin
Invoke-SafeDiskCleanup -Clean -DaysOld 3 -EmptyRecycleBin

# Generate and save HTML health report without automatically opening browser
New-HealthReport -OutputPath "C:\Reports\health.html" -NoOpen

# Inspect weekly maintenance schedule status
Register-ToolkitScheduledTask -Action Status
```

---

## Safety Standards & Guardrails

Maintenance tools must never cause accidental data loss or crash in production. LaptopToolkit enforces:

1. **Path Safety Assertions**: Every cleanup routine validates target directories against `Assert-SafePath`, strictly blocking root drives (`C:\`), Windows directories, and user profile roots.
2. **Discovery-First Analysis**: Disk cleaning calculates reclaimable space and displays candidate statistics first. Mutation requires an explicit `-Clean` switch or user confirmation.
3. **Dry-Run (`-WhatIf`) Support**: All mutating cmdlets implement `[CmdletBinding(SupportsShouldProcess = $true)]`.
4. **Locked-File Fault Tolerance**: In-use files locked by active processes (e.g., browser or IDE caches) are caught via `[System.IO.IOException]` and skipped gracefully without interrupting cleanup.
5. **Audit Trail**: Operational summaries and reclaimed space are logged to `$HOME\LaptopToolkit\Reports\toolkit-history.log`.

---

## Configuration (`config.json`)

You can customize warning thresholds and tools list in `src/config.json`:

```json
{
  "thresholds": {
    "cpuWarningPercent": 80,
    "ramWarningPercent": 75,
    "diskFreeWarningPercent": 15
  },
  "maintenance": {
    "tempRetentionDays": 2,
    "emptyRecycleBin": true
  },
  "developerTools": [
    "git", "node", "npm", "python", "docker", "code", "cargo", "go"
  ]
}
```

---

## Contributing

We welcome issues and pull requests! Please review our [Contributing Guidelines](CONTRIBUTING.md) and ensure that tests pass:

```powershell
# Run Pester test suite
Invoke-Pester -Path ./tests
```

---

## License

Released under the [MIT License](LICENSE).

## Configuration

Settings live in `src/config.json` (thresholds, temp retention, DNS probe targets, developer tool list).
To change them without losing your edits on re-install, create `%USERPROFILE%\LaptopToolkit\config.json`
containing only the keys you want to override, for example:

```json
{ "maintenance": { "tempRetentionDays": 7 }, "thresholds": { "ramWarningPercent": 70 } }
```

Invalid values fall back to safe defaults. Emptying the Recycle Bin is **off by default** and only happens
if you pass `-EmptyRecycleBin` or set `maintenance.emptyRecycleBin` to `true` in your own override file.
