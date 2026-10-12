function Get-FileTree {
    <#
    .SYNOPSIS
        Lists files under a root without following junctions/symlinks (no loops, no escaping the root).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Root)

    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        $entries = Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue
        foreach ($e in $entries) {
            if ($e.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
            if ($e.PSIsContainer) { $stack.Push($e.FullName) } else { $e }
        }
    }
}
