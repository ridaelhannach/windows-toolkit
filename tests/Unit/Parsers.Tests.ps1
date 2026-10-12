BeforeAll {
    Import-Module (Join-Path $PSScriptRoot "../../src/LaptopToolkit.psd1") -Force
}

Describe "Wi-Fi parsers" {
    It "Parses a connected interface and rates it" {
        InModuleScope LaptopToolkit {
            $text = @'
    Name                   : Wi-Fi
    State                  : connected
    SSID                   : HomeNet
    BSSID                  : 11:22:33:44:55:66
    Radio type             : 802.11ax
    Authentication         : WPA2-Personal
    Cipher                 : CCMP
    Band                   : 2.4 GHz
    Channel                : 6
    Receive rate (Mbps)    : 144.4
    Transmit rate (Mbps)   : 130
    Signal                 : 72%
'@
            $i = ConvertFrom-NetshWlanInterface -Text $text
            $i.Ssid | Should -Be "HomeNet"
            $i.Bssid | Should -Be "11:22:33:44:55:66"
            $i.Channel | Should -Be 6
            $i.SignalPercent | Should -Be 72
            $i.SignalQuality | Should -Be "Good"
            $i.SecurityRating | Should -Be "OK"
        }
    }

    It "Returns nothing when the WLAN service is not running" {
        InModuleScope LaptopToolkit {
            @(ConvertFrom-NetshWlanInterface -Text "The Wireless AutoConfig Service (wlansvc) is not running.").Count | Should -Be 0
        }
    }

    It "Rates security correctly" {
        InModuleScope LaptopToolkit {
            Get-WifiSecurityRating "Open" "" | Should -Be "Weak"
            Get-WifiSecurityRating "WPA2-Personal" "TKIP" | Should -Be "Weak"
            Get-WifiSecurityRating "WPA-Personal" "CCMP" | Should -Be "Weak"
            Get-WifiSecurityRating "WPA2-Personal" "CCMP" | Should -Be "OK"
            Get-WifiSecurityRating "WPA3-Personal" "CCMP" | Should -Be "Strong"
        }
    }

    It "Parses nearby networks, keeping SSID for each BSSID and flagging hidden/open" {
        InModuleScope LaptopToolkit {
            $text = @'
SSID 1 : HomeNet
    Authentication          : WPA2-Personal
    Encryption              : CCMP
    BSSID 1                 : 11:22:33:44:55:66
         Signal             : 72%
         Band               : 2.4 GHz
         Channel            : 6
    BSSID 2                 : 11:22:33:44:55:67
         Signal             : 90%
         Band               : 5 GHz
         Channel            : 44

SSID 2 : 
    Authentication          : Open
    Encryption              : None
    BSSID 1                 : aa:aa:aa:aa:aa:aa
         Signal             : 30%
         Channel            : 6
'@
            $n = @(ConvertFrom-NetshWlanNetwork -Text $text)
            $n.Count | Should -Be 3
            ($n | Where-Object Bssid -eq "11:22:33:44:55:67").Ssid | Should -Be "HomeNet"
            $open = $n | Where-Object Bssid -eq "aa:aa:aa:aa:aa:aa"
            $open.Ssid | Should -Be "(hidden)"
            $open.SecurityRating | Should -Be "Weak"
            $open.Band | Should -Be "2.4 GHz"
        }
    }
}

Describe "ConvertFrom-WingetUpgrade" {
    It "Parses rows using header positions and ignores spinner and footer lines" {
        InModuleScope LaptopToolkit {
            $text = @"
   - 
   \ 
Name                         Id                    Version   Available Source
-------------------------------------------------------------------------------
Git                          Git.Git               2.44.0    2.45.1    winget
7-Zip 23.01 (x64)            7zip.7zip             23.01     24.07     winget
2 upgrades available.
"@
            $p = @(ConvertFrom-WingetUpgrade -Text $text)
            $p.Count | Should -Be 2
            $p[0].Id | Should -Be "Git.Git"
            $p[0].Available | Should -Be "2.45.1"
            $p[1].Name | Should -Be "7-Zip 23.01 (x64)"
        }
    }

    It "Returns nothing when there is no table" {
        InModuleScope LaptopToolkit {
            @(ConvertFrom-WingetUpgrade -Text "No installed package found matching input criteria.").Count | Should -Be 0
        }
    }
}

Describe "Git helpers" {
    It "Parses branch status headers" {
        InModuleScope LaptopToolkit {
            $a = ConvertFrom-GitStatusBranch -Line "## main...origin/main [ahead 2, behind 1]"
            $a.Branch | Should -Be "main"
            $a.Ahead | Should -Be 2
            $a.Behind | Should -Be 1
            (ConvertFrom-GitStatusBranch -Line "## HEAD (no branch)").Detached | Should -BeTrue
            (ConvertFrom-GitStatusBranch -Line "## x...origin/x [gone]").UpstreamGone | Should -BeTrue
            (ConvertFrom-GitStatusBranch -Line "## No commits yet on main").Branch | Should -Be "main"
        }
    }

    It "Masks credentials embedded in remote URLs" {
        InModuleScope LaptopToolkit {
            Hide-UrlCredential "https://user:ghp_SECRET@github.com/o/r.git" | Should -Be "https://***@github.com/o/r.git"
            Hide-UrlCredential "git@github.com:o/r.git" | Should -Be "git@github.com:o/r.git"
        }
    }
}

Describe "Find-DuplicateFile" {
    BeforeEach {
        $script:dir = Join-Path ([System.IO.Path]::GetTempPath()) ("dup-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path (Join-Path $script:dir "sub") -Force | Out-Null
        $bytes = New-Object byte[] 1048576
        (New-Object System.Random 1).NextBytes($bytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:dir "a.bin"), $bytes)
        [System.IO.File]::WriteAllBytes((Join-Path $script:dir "sub/b.bin"), $bytes)
        $other = New-Object byte[] 1048576
        (New-Object System.Random 2).NextBytes($other)
        [System.IO.File]::WriteAllBytes((Join-Path $script:dir "c.bin"), $other)
    }
    AfterEach { Remove-Item $script:dir -Recurse -Force -ErrorAction SilentlyContinue }

    It "Groups identical content only, and deletes nothing" {
        $r = Find-DuplicateFile -Path $script:dir -MinSizeMB 0 -PassThru
        $r.DuplicateGroups | Should -Be 1
        $r.Groups[0].Copies | Should -Be 2
        ($r.Groups[0].Files -join ";") | Should -Not -Match "c\.bin"
        (Get-ChildItem $script:dir -Recurse -File).Count | Should -Be 3
    }
}
