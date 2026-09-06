[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $PackageDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packagePath = [System.IO.Path]::GetFullPath($PackageDirectory)
if (-not (Test-Path -LiteralPath $packagePath -PathType Container)) {
    throw "Windows package directory was not found: $packagePath"
}

$binaries = @(
    Get-ChildItem -LiteralPath $packagePath -File -Force -Recurse |
        Where-Object { $_.Extension -in @('.exe', '.dll') }
)
if ($binaries.Count -eq 0) {
    throw "Windows package does not contain application binaries."
}

$invalid = @()
foreach ($binary in $binaries) {
    $signature = Get-AuthenticodeSignature -LiteralPath $binary.FullName
    if ($signature.Status -ne
        [System.Management.Automation.SignatureStatus]::Valid)
    {
        $relativePath = [System.IO.Path]::GetRelativePath(
            $packagePath,
            $binary.FullName)
        $invalid += "$relativePath`: $($signature.Status)"
    }
}
if ($invalid.Count -ne 0) {
    throw "Windows package contains untrusted binaries: $($invalid -join ', ')"
}

Write-Output "TOKENI_WINDOWS_SIGNATURES_OK"
