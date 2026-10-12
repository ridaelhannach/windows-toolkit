BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "../../src/LaptopToolkit.psd1"
}

Describe "LaptopToolkit Module Integrity" {
    It "Has a valid module manifest" {
        Test-Path $script:manifestPath | Should -BeTrue
        $manifest = Test-ModuleManifest -Path $script:manifestPath
        $manifest.Name | Should -Be "LaptopToolkit"
        $manifest.Version.ToString() | Should -Be "1.0.0"
    }

    It "Imports without errors and exports every documented function" {
        $expected = (Import-PowerShellDataFile -Path $script:manifestPath).FunctionsToExport
        { Import-Module $script:manifestPath -Force -ErrorAction Stop } | Should -Not -Throw
        $exported = (Get-Command -Module LaptopToolkit).Name
        foreach ($fn in $expected) { $exported | Should -Contain $fn }
    }

    It "Exports the 'toolkit' alias" {
        Import-Module $script:manifestPath -Force
        Get-Command toolkit -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
    }

    It "Uses no PowerShell 7-only syntax (manifest promises 5.1)" {
        $files = Get-ChildItem (Join-Path $PSScriptRoot "../../src") -Recurse -Filter *.ps1
        foreach ($f in $files) {
            $tokens = $null; $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
            $ps7 = $ast.FindAll({
                param($n)
                $n.GetType().Name -in @("TernaryExpressionAst", "PipelineChainAst") -or
                ($n.GetType().Name -eq "BinaryExpressionAst" -and $n.Operator -in @("QuestionQuestion"))
            }, $true)
            $ps7.Count | Should -Be 0 -Because "$($f.Name) must parse on Windows PowerShell 5.1"
        }
    }
}
