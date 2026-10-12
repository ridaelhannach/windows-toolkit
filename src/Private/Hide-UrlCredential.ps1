function Hide-UrlCredential {
    <# Masks user:password@ (e.g. an access token) embedded in a URL before it is displayed or stored. #>
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Url)
    if (-not $Url) { return $Url }
    $Url -replace '://[^/@\s]+@', '://***@'
}
