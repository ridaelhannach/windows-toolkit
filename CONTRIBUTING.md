# Contributing to LaptopToolkit

Thank you for your interest in improving LaptopToolkit! We welcome contributions from systems administrators, developers, students, and PowerShell enthusiasts.

---

## Code of Conduct

Please maintain a collaborative, respectful, and constructive environment in issues and pull requests.

---

## Development Setup

1. **Fork and Clone** the repository:
   ```powershell
   git clone https://github.com/<your-username>/windows-toolkit.git
   cd windows-toolkit
   ```

2. **Import the Development Module**:
   ```powershell
   Import-Module ./src/LaptopToolkit.psd1 -Force
   ```

3. **Install Development Tools**:
   ```powershell
   Install-Module -Name Pester -MinimumVersion 5.3.0 -Scope CurrentUser
   Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
   ```

---

## Safety Standards (Mandatory)

Any pull request that introduces state-changing or cleanup routines MUST adhere to these guidelines:

1. **Dry-Run & Confirmation**: Implement `[CmdletBinding(SupportsShouldProcess = $true)]` and guard all mutations with `$PSCmdlet.ShouldProcess()`.
2. **Path Guards**: Assert paths using `Assert-SafePath` to strictly prevent targeting system roots (`C:\`, `$HOME`, `C:\Windows`).
3. **Discovery Mode Default**: Non-interactive or destructive actions must require an explicit switch (e.g., `-Clean`).
4. **Locked File Handling**: Never suppress errors globally. Catch `[System.IO.IOException]` specifically to skip files in use.

---

## Running Tests

Before submitting a Pull Request, run the linter and unit test suite:

```powershell
# Run PSScriptAnalyzer
Invoke-ScriptAnalyzer -Path ./src -Settings ./PSScriptAnalyzerSettings.psd1 -Recurse

# Run Pester Tests
Invoke-Pester -Path ./tests
```

All PRs must pass CI checks on both Windows PowerShell 5.1 and PowerShell Core 7+.
