[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $PackageDirectory,

    [Parameter(Mandatory = $true)]
    [string] $CatalogPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$packagePath = [System.IO.Path]::GetFullPath($PackageDirectory)
$catalogFilePath = [System.IO.Path]::GetFullPath($CatalogPath)
$catalogDirectory = [System.IO.Path]::GetDirectoryName($catalogFilePath)

if (-not (Test-Path -LiteralPath $packagePath -PathType Container)) {
    throw "Windows package directory was not found: $packagePath"
}
if (-not (Test-Path `
        -LiteralPath (Join-Path $packagePath "TokeniWindows.exe") `
        -PathType Leaf))
{
    throw "Windows package does not contain TokeniWindows.exe."
}
if (-not (Test-Path -LiteralPath $catalogDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $catalogDirectory -Force | Out-Null
}

$unsignedFiles = @(
    Get-ChildItem -LiteralPath $packagePath -File -Force -Recurse |
        Where-Object { $_.Extension -in @('.exe', '.dll') } |
        Where-Object {
            (Get-AuthenticodeSignature -LiteralPath $_.FullName).Status -ne
                [System.Management.Automation.SignatureStatus]::Valid
        }
)
if ($unsignedFiles.Count -eq 0) {
    throw "Windows package does not contain any unsigned application binaries."
}
if (-not ($unsignedFiles.Name -ccontains "TokeniWindows.exe")) {
    throw "TokeniWindows.exe was already signed before the release signing step."
}

$catalogLines = $unsignedFiles |
    Sort-Object -Property FullName |
    ForEach-Object {
        [System.IO.Path]::GetRelativePath($catalogDirectory, $_.FullName)
    }
$catalogEncoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllLines(
    $catalogFilePath,
    [string[]] $catalogLines,
    $catalogEncoding)

Write-Output $catalogFilePath
