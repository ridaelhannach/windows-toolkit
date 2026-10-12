BeforeAll {
    $script:manifestPath = Join-Path $PSScriptRoot "../../src/LaptopToolkit.psd1"
    Import-Module $script:manifestPath -Force
}

Describe "Get-ToolkitConfig" {
    BeforeEach {
        $script:fakeHome = Join-Path ([System.IO.Path]::GetTempPath()) ("lt-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $script:fakeHome "LaptopToolkit") -Force | Out-Null
    }
    AfterEach { Remove-Item $script:fakeHome -Recurse -Force -ErrorAction SilentlyContinue }

    It "Ships with the Recycle Bin purge disabled" {
        InModuleScope LaptopToolkit {
            $shipped = Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) "config.json") -Raw | ConvertFrom-Json
            $shipped.maintenance.emptyRecycleBin | Should -BeFalse
        }
    }

    It "Applies a user override on top of shipped values" {
        InModuleScope LaptopToolkit -Parameters @{ H = $script:fakeHome } {
            param($H)
            Set-Content (Join-Path $H "LaptopToolkit\config.json") '{"maintenance":{"tempRetentionDays":9}}'
            $HOME = $H
            (Get-ToolkitConfig -Reload).Maintenance.tempRetentionDays | Should -Be 9
        }
    }

    It "Falls back to defaults on invalid values and malformed JSON" {
        InModuleScope LaptopToolkit -Parameters @{ H = $script:fakeHome } {
            param($H)
            Set-Content (Join-Path $H "LaptopToolkit\config.json") '{"thresholds":{"cpuWarningPercent":"abc"},'
            $HOME = $H
            (Get-ToolkitConfig -Reload).Thresholds.cpuWarningPercent | Should -Be 80
        }
    }

    It "Rejects tool names with shell metacharacters" {
        InModuleScope LaptopToolkit -Parameters @{ H = $script:fakeHome } {
            param($H)
            Set-Content (Join-Path $H "LaptopToolkit\config.json") '{"developerTools":["git","x; calc"]}'
            $HOME = $H
            (Get-ToolkitConfig -Reload).DeveloperTools | Should -Be @("git")
        }
    }
}
