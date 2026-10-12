function Find-GitRepository {
    <#
    .SYNOPSIS
        Finds git working directories under a root, to a maximum depth. Read-only.
    .DESCRIPTION
        Does not descend into a repository once found, and skips junctions/symlinks and
        well-known dependency or build folders.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [ValidateRange(0, 8)][int]$Depth = 3
    )

    $skip = @("node_modules", ".git", "bin", "obj", ".venv", "venv", "__pycache__", "target", "dist", "build", '$RECYCLE.BIN', "AppData")
    $stack = New-Object System.Collections.Stack
    $stack.Push(@($Root, 0))

    while ($stack.Count -gt 0) {
        $item = $stack.Pop()
        $dir = $item[0]; $level = $item[1]

        if (Test-Path -LiteralPath (Join-Path $dir ".git")) {
            $dir
            continue
        }
        if ($level -ge $Depth) { continue }

        $children = Get-ChildItem -LiteralPath $dir -Directory -Force -ErrorAction SilentlyContinue
        foreach ($c in $children) {
            if ($c.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
            if ($skip -contains $c.Name) { continue }
            $stack.Push(@($c.FullName, ($level + 1)))
        }
    }
}
