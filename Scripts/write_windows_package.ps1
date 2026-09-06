[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Version must use x.y.z format: $Version"
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
} else {
    $outputPath = [System.IO.Path]::GetFullPath(
        (Join-Path $projectDirectory $OutputDirectory))
}

$normalizedPath = $outputPath.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar)
$normalizedRoot = $projectDirectory.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar)
$driveRoot = [System.IO.Path]::GetPathRoot($outputPath).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar)
if ([string]::Equals(
        $normalizedPath,
        $normalizedRoot,
        [System.StringComparison]::OrdinalIgnoreCase) -or
    [string]::Equals(
        $normalizedPath,
        $driveRoot,
        [System.StringComparison]::OrdinalIgnoreCase))
{
    throw "Refusing unsafe output directory: $outputPath"
}

$packageName = "Tokeni-Bar-Windows-$Version"
$stagingPath = Join-Path $outputPath $packageName
$archivePath = Join-Path $outputPath "$packageName.zip"
$checksumPath = "$archivePath.sha256"

if (-not (Test-Path -LiteralPath $stagingPath -PathType Container)) {
    throw "Windows package staging directory was not found: $stagingPath"
}
if (-not (Test-Path `
        -LiteralPath (Join-Path $stagingPath "TokeniWindows.exe") `
        -PathType Leaf))
{
    throw "Windows package staging directory does not contain TokeniWindows.exe."
}

$sqlitePath = Join-Path $stagingPath "Tools\sqlite3.exe"
$sqliteManifestPath = Join-Path $stagingPath "Tools\sqlite-tools.json"
if (-not (Test-Path -LiteralPath $sqlitePath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $sqliteManifestPath -PathType Leaf))
{
    throw "Windows package staging directory does not contain pinned SQLite metadata."
}
$sqliteManifest = Get-Content -LiteralPath $sqliteManifestPath -Raw |
    ConvertFrom-Json
if ($sqliteManifest.executable_sha256 -notmatch '^[0-9a-f]{64}$') {
    throw "Pinned SQLite manifest does not contain a valid upstream executable hash."
}
$packagedSQLiteHash = (Get-FileHash `
    -LiteralPath $sqlitePath `
    -Algorithm SHA256).Hash.ToLowerInvariant()
$sqliteManifest | Add-Member `
    -NotePropertyName packaged_executable_sha256 `
    -NotePropertyValue $packagedSQLiteHash `
    -Force
$manifestJSON = $sqliteManifest | ConvertTo-Json -Depth 8
$manifestEncoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText(
    $sqliteManifestPath,
    "$manifestJSON`n",
    $manifestEncoding)

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}

Compress-Archive -Path (Join-Path $stagingPath '*') `
    -DestinationPath $archivePath `
    -CompressionLevel Optimal

$archiveHash = (Get-FileHash `
    -LiteralPath $archivePath `
    -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumLine = "$archiveHash  $([System.IO.Path]::GetFileName($archivePath))`n"
$checksumEncoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText(
    $checksumPath,
    $checksumLine,
    $checksumEncoding)

Write-Output $archivePath
