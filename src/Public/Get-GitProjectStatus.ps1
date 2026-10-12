function Get-GitProjectStatus {
    <#
    .SYNOPSIS
        Scans folders for git repositories and reports uncommitted work, unpushed commits, and stashes.
    .DESCRIPTION
        Read-only apart from the optional -Fetch. Safe against hostile repositories: git is run with
        core.fsmonitor disabled so a repo's own config cannot execute programs during 'status', terminal
        prompts are disabled, and credentials embedded in remote URLs are masked in the output.
        Ahead/behind counts reflect the last fetch unless -Fetch is used.
    .PARAMETER Path
        Folders to scan. Defaults to git.scanRoots in config.json, or common project folders that exist.
    .PARAMETER Depth
        How deep to search for repositories. Defaults to git.maxDepth in config.json.
    .PARAMETER Fetch
        Run 'git fetch' first so ahead/behind is current. Uses the network and may prompt for nothing (prompts are disabled).
    .PARAMETER NeedsAttentionOnly
        Show only repositories with uncommitted changes, unpushed commits, or new commits upstream.
    .PARAMETER PassThru
        Return the repository objects instead of printing them.
    #>
    [CmdletBinding()]
    param(
        [string[]]$Path,
        [ValidateRange(1, 6)]
        [int]$Depth,
        [switch]$Fetch,
        [switch]$NeedsAttentionOnly,
        [switch]$PassThru
    )

    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        Write-Host "git was not found on PATH." -ForegroundColor Yellow
        if ($PassThru) { return @() }
        return
    }

    $cfg = Get-ToolkitConfig
    if (-not $PSBoundParameters.ContainsKey('Depth')) { $Depth = $cfg.Git.maxDepth }
    if (-not $Path -or $Path.Count -eq 0) {
        $Path = @($cfg.Git.scanRoots)
        if ($Path.Count -eq 0) {
            $Path = @(
                (Join-Path $HOME "source\repos"), (Join-Path $HOME "Documents\GitHub"),
                (Join-Path $HOME "repos"), (Join-Path $HOME "Projects"), (Join-Path $HOME "dev")
            )
        }
    }
    $roots = @($Path | ForEach-Object { [Environment]::ExpandEnvironmentVariables($_) } |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } |
        ForEach-Object { (Resolve-Path -LiteralPath $_).ProviderPath } | Select-Object -Unique)

    if ($roots.Count -eq 0) {
        Write-Host "No project folders found. Pass -Path <folder> or set git.scanRoots in your config." -ForegroundColor Yellow
        if ($PassThru) { return @() }
        return
    }

    $savedPrompt = $env:GIT_TERMINAL_PROMPT
    $savedLocks = $env:GIT_OPTIONAL_LOCKS
    $env:GIT_TERMINAL_PROMPT = "0"
    $env:GIT_OPTIONAL_LOCKS = "0"
    $repos = New-Object System.Collections.Generic.List[object]
    try {
        $seen = @{}
        foreach ($root in $roots) {
            foreach ($repoPath in (Find-GitRepository -Root $root -Depth $Depth)) {
                if ($seen.ContainsKey($repoPath)) { continue }
                $seen[$repoPath] = $true
                $g = @("-c", "core.fsmonitor=false", "-C", $repoPath)

                if ($Fetch) { & $git.Source @g fetch --quiet --no-tags 2>&1 | Out-Null }

                $statusOut = @(& $git.Source @g status --porcelain=v1 -b 2>&1 | ForEach-Object { "$_" })
                if ($LASTEXITCODE -ne 0) {
                    $repos.Add([PSCustomObject]@{
                        Repo = (Split-Path $repoPath -Leaf); Path = $repoPath; Branch = $null; Upstream = $null
                        Ahead = 0; Behind = 0; Modified = 0; Untracked = 0; Stashes = 0; LastCommit = $null
                        DaysSinceCommit = $null; Remote = $null; State = "Unreadable"; NeedsAttention = $false
                        Note = ($statusOut | Select-Object -First 1)
                    })
                    continue
                }

                $header = $statusOut | Where-Object { $_ -like "##*" } | Select-Object -First 1
                $b = if ($header) { ConvertFrom-GitStatusBranch -Line $header } else { ConvertFrom-GitStatusBranch -Line "## (unknown)" }
                $entries = @($statusOut | Where-Object { $_ -and $_ -notlike "##*" })
                $untracked = @($entries | Where-Object { $_.StartsWith("??") }).Count   # note: -like would treat ? as a wildcard
                $modified = $entries.Count - $untracked

                $stashes = @(& $git.Source @g stash list 2>$null).Count
                $lastIso = & $git.Source @g log -1 --format=%cI 2>$null
                $last = $null
                if ($LASTEXITCODE -eq 0 -and $lastIso) { $last = [datetime]::Parse(($lastIso | Select-Object -First 1)) }
                $remote = & $git.Source @g remote get-url origin 2>$null
                if ($LASTEXITCODE -ne 0) { $remote = $null }

                $dirty = ($modified + $untracked) -gt 0
                $state = "Clean"
                if ($b.Detached) { $state = "Detached" }
                elseif ($b.Ahead -gt 0 -and $b.Behind -gt 0) { $state = "Diverged" }
                elseif ($dirty) { $state = "Dirty" }
                elseif ($b.Ahead -gt 0) { $state = "Ahead" }
                elseif ($b.Behind -gt 0) { $state = "Behind" }
                elseif (-not $b.Upstream) { $state = "No upstream" }
                elseif ($b.UpstreamGone) { $state = "Upstream gone" }

                $repos.Add([PSCustomObject]@{
                    Repo            = (Split-Path $repoPath -Leaf)
                    Path            = $repoPath
                    Branch          = $b.Branch
                    Upstream        = $b.Upstream
                    Ahead           = $b.Ahead
                    Behind          = $b.Behind
                    Modified        = $modified
                    Untracked       = $untracked
                    Stashes         = $stashes
                    LastCommit      = $last
                    DaysSinceCommit = if ($last) { [int]((Get-Date) - $last).TotalDays } else { $null }
                    Remote          = Hide-UrlCredential -Url ([string]($remote | Select-Object -First 1))
                    State           = $state
                    NeedsAttention  = ($dirty -or $b.Ahead -gt 0 -or $b.Behind -gt 0)
                    Note            = $null
                })
            }
        }
    } finally {
        $env:GIT_TERMINAL_PROMPT = $savedPrompt
        $env:GIT_OPTIONAL_LOCKS = $savedLocks
    }

    $out = @($repos | Sort-Object @{ Expression = "NeedsAttention"; Descending = $true }, Repo)
    if ($NeedsAttentionOnly) { $out = @($out | Where-Object NeedsAttention) }
    Write-ToolkitLog "Git scan: $($repos.Count) repo(s), $(@($repos | Where-Object NeedsAttention).Count) need attention" "INFO"

    if ($PassThru) { return $out }

    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                GIT PROJECT STATUS (READ-ONLY)              " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ("Scanned {0} folder(s); found {1} repositor{2}." -f $roots.Count, $repos.Count, $(if ($repos.Count -eq 1) { "y" } else { "ies" }))
    if ($out.Count -eq 0) {
        Write-Host "Nothing to show." -ForegroundColor Green
        return
    }
    $out | Format-Table Repo, Branch, State, Ahead, Behind, Modified, Untracked, Stashes, DaysSinceCommit -AutoSize
    if (-not $Fetch) {
        Write-Host "Ahead/behind reflects your last fetch. Use -Fetch for current numbers." -ForegroundColor DarkGray
    }
}
