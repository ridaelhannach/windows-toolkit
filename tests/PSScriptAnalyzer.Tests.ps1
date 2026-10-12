Describe "PSScriptAnalyzer Lint Verification" {
    It "Contains no PSScriptAnalyzer Errors in src/" {
        if (Get-Command Invoke-ScriptAnalyzer -ErrorAction SilentlyContinue) {
            $settingsPath = "$PSScriptRoot/../PSScriptAnalyzerSettings.psd1"
            $results = Invoke-ScriptAnalyzer -Path "$PSScriptRoot/../src" -Settings $settingsPath -Recurse
            $errors = $results | Where-Object { $_.Severity -eq 'Error' }
            $errors.Count | Should -Be 0
        } else {
            Set-ItResult -Skipped -Because "PSScriptAnalyzer module is not installed in current environment"
        }
    }
}
