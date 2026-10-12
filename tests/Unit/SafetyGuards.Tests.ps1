BeforeAll {
    . "$PSScriptRoot/../../src/Private/Assert-SafePath.ps1"
}

Describe "Assert-SafePath Safety Guardrails" {
    Context "Null and Empty Validation" {
        It "Throws when path is null or empty" {
            { Assert-SafePath -Path "" } | Should -Throw
            { Assert-SafePath -Path "   " } | Should -Throw
            { Assert-SafePath -Path $null } | Should -Throw
        }
    }

    Context "System Root Protection" {
        It "Rejects System Drive root" {
            $driveRoot = if ($env:SystemDrive) { "$($env:SystemDrive)\" } else { "C:\" }
            { Assert-SafePath -Path $driveRoot } | Should -Throw "*Safety guard triggered*"
        }

        It "Rejects Windows Directory root" {
            if ($env:SystemRoot) {
                { Assert-SafePath -Path $env:SystemRoot } | Should -Throw "*Safety guard triggered*"
            }
        }

        It "Rejects User Profile root" {
            if ($env:USERPROFILE) {
                { Assert-SafePath -Path $env:USERPROFILE } | Should -Throw "*Safety guard triggered*"
            }
        }
    }

    Context "Safe Directory Allowance" {
        It "Allows subdirectories inside Temp" {
            $tempSub = Join-Path ([System.IO.Path]::GetTempPath()) "ToolkitTestSafeDir"
            { Assert-SafePath -Path $tempSub } | Should -Not -Throw
        }
    }
}
