function Assert-SafePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "Path cannot be null, empty, or whitespace."
    }

    $resolved = (Resolve-Path -Path $Path -ErrorAction SilentlyContinue).Path
    if (-not $resolved) {
        $resolved = [System.IO.Path]::GetFullPath($Path)
    }

    $systemDrive = if ($env:SystemDrive) { $env:SystemDrive + "\" } else { "C:\" }
    $forbidden = @(
        $systemDrive,
        $env:SystemRoot,
        $env:ProgramFiles,
        ${env:ProgramFiles(x86)},
        $env:USERPROFILE
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

    foreach ($f in $forbidden) {
        $normF = [System.IO.Path]::GetFullPath($f).TrimEnd('\')
        $normR = [System.IO.Path]::GetFullPath($resolved).TrimEnd('\')
        if ($normF -eq $normR) {
            throw "Safety guard triggered: Refusing to perform destructive operation on protected system or profile root: $resolved"
        }
    }
}
