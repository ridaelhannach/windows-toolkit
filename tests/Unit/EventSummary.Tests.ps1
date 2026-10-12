BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../../src/LaptopToolkit.psd1") -Force
}

Describe "ConvertTo-EventSummary" {
    BeforeAll {
        function New-Ev($Log, $Prov, $Id, $Level, $Hours, $Msg = "") {
            [PSCustomObject]@{ LogName = $Log; ProviderName = $Prov; Id = $Id; Level = $Level
                               TimeCreated = (Get-Date).AddHours(-$Hours); Message = $Msg }
        }
        $script:events = @(
            (New-Ev System "Microsoft-Windows-Kernel-Power" 41 1 5 "The system rebooted without cleanly shutting down."),
            (New-Ev System "Microsoft-Windows-Kernel-Power" 41 1 30),
            (New-Ev Application "Application Error" 1000 2 2 "Faulting application x.exe`nline two"),
            (New-Ev Application "Application Error" 1000 2 3),
            (New-Ev Application "Application Error" 1000 2 4),
            (New-Ev System "Some-Noisy-Service" 7 3 1 "warn")
        )
    }

    It "Handles an empty event list" {
        InModuleScope LaptopToolkit {
            $r = ConvertTo-EventSummary -Events @()
            $r.TotalEvents | Should -Be 0
            $r.NeedsAttention | Should -BeFalse
        }
    }

    It "Counts levels and ranks recurring events" {
        InModuleScope LaptopToolkit -Parameters @{ E = $script:events } {
            param($E)
            $r = ConvertTo-EventSummary -Events $E
            $r.Critical | Should -Be 2
            $r.Errors   | Should -Be 3
            $r.Warnings | Should -Be 1
            $r.TopEvents[0].Source  | Should -Be "Application Error"
            $r.TopEvents[0].Count   | Should -Be 3
            $r.TopEvents[0].Sample  | Should -Be "Faulting application x.exe"
        }
    }

    It "Flags unexpected shutdowns as needing attention" {
        InModuleScope LaptopToolkit -Parameters @{ E = $script:events } {
            param($E)
            $r = ConvertTo-EventSummary -Events $E
            $r.NeedsAttention | Should -BeTrue
            ($r.KnownIssues | Where-Object Source -eq "Microsoft-Windows-Kernel-Power").Count | Should -Be 2
        }
    }

    It "Does not treat app crashes alone as serious" {
        InModuleScope LaptopToolkit -Parameters @{ E = $script:events } {
            param($E)
            $r = ConvertTo-EventSummary -Events @($E | Where-Object ProviderName -eq "Application Error")
            $r.NeedsAttention | Should -BeFalse
        }
    }
}
