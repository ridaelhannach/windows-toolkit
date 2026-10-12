function ConvertFrom-GitStatusBranch {
    <#
    .SYNOPSIS
        Parses the '## ...' header line of 'git status --porcelain=v1 -b'. Pure function.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Line)

    $l = ($Line -replace '^##\s*', '').Trim()
    $r = [ordered]@{ Branch = $l; Upstream = $null; Ahead = 0; Behind = 0; Detached = $false; UpstreamGone = $false }

    if ($l -match '^HEAD \(no branch\)') {
        $r.Branch = "(detached)"; $r.Detached = $true
    } elseif ($l -match '^(?:No commits yet on|Initial commit on)\s+(.+)$') {
        $r.Branch = $Matches[1].Trim()
    } elseif ($l -match '^(?<b>.+?)\.\.\.(?<u>\S+)(?:\s+\[(?<t>[^\]]+)\])?$') {
        $r.Branch = $Matches['b']; $r.Upstream = $Matches['u']
        $t = $Matches['t']
        if ($t) {
            if ($t -match 'gone') { $r.UpstreamGone = $true }
            if ($t -match 'ahead (\d+)') { $r.Ahead = [int]$Matches[1] }
            if ($t -match 'behind (\d+)') { $r.Behind = [int]$Matches[1] }
        }
    }
    [PSCustomObject]$r
}
