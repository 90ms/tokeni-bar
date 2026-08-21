[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $BuildDirectory,

    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,

    [string[]] $RuntimeDirectory = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectDirectory = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$versionPattern = '^\d+\.\d+\.\d+$'
if ($Version -notmatch $versionPattern) {
    throw "Version must use x.y.z format: $Version"
}

function Resolve-InputPath {
    param([string] $Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $projectDirectory $Path))
}

function Assert-SafeOutputDirectory {
    param([string] $Path)

    $normalizedPath = $Path.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $normalizedRoot = $projectDirectory.TrimEnd([System.IO.Path]::DirectorySeparatorChar)
    $driveRoot = [System.IO.Path]::GetPathRoot($Path).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar)
    if ([string]::Equals($normalizedPath, $normalizedRoot,
            [System.StringComparison]::OrdinalIgnoreCase) -or
        [string]::Equals($normalizedPath, $driveRoot,
            [System.StringComparison]::OrdinalIgnoreCase))
    {
        throw "Refusing unsafe output directory: $Path"
    }
}

$buildPath = Resolve-InputPath $BuildDirectory
$outputPath = Resolve-InputPath $OutputDirectory
Assert-SafeOutputDirectory $outputPath

if (-not (Test-Path -LiteralPath $buildPath -PathType Container)) {
    throw "Build directory does not exist: $buildPath"
}

$binaryPath = Join-Path $buildPath "TokeniWindows.exe"
if (-not (Test-Path -LiteralPath $binaryPath -PathType Leaf)) {
    throw "TokeniWindows.exe was not found in: $buildPath"
}

$companionAssetSourcePath = Join-Path `
    $projectDirectory `
    "Sources\TokeniBar\CompanionAssets"
if (-not (Test-Path -LiteralPath $companionAssetSourcePath -PathType Container)) {
    throw "Companion asset source directory was not found: $companionAssetSourcePath"
}

New-Item -ItemType Directory -Path $outputPath -Force | Out-Null

$packageName = "Tokeni-Bar-Windows-$Version"
$stagingPath = Join-Path $outputPath $packageName
$archivePath = Join-Path $outputPath "$packageName.zip"
$checksumPath = "$archivePath.sha256"

if (Test-Path -LiteralPath $stagingPath) {
    Remove-Item -LiteralPath $stagingPath -Recurse -Force
}
if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}
if (Test-Path -LiteralPath $checksumPath) {
    Remove-Item -LiteralPath $checksumPath -Force
}
New-Item -ItemType Directory -Path $stagingPath -Force | Out-Null

$filesToCopy = Get-ChildItem -LiteralPath $buildPath -File -Force |
    Where-Object { $_.Extension -in @('.exe', '.dll') }
foreach ($file in $filesToCopy) {
    Copy-Item -LiteralPath $file.FullName -Destination $stagingPath -Force
}

foreach ($runtimePath in $RuntimeDirectory) {
    if (-not (Test-Path -LiteralPath $runtimePath -PathType Container)) {
        throw "Swift runtime directory does not exist: $runtimePath"
    }
    Get-ChildItem -LiteralPath $runtimePath -File -Force |
        Where-Object { $_.Extension -eq '.dll' } |
        ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $stagingPath -Force
        }
}

$resourcesToCopy = Get-ChildItem -LiteralPath $buildPath -Directory -Force |
    Where-Object {
        $_.Name.EndsWith('.bundle', [System.StringComparison]::OrdinalIgnoreCase) -or
            $_.Name.EndsWith('.resources', [System.StringComparison]::OrdinalIgnoreCase)
    }
foreach ($resource in $resourcesToCopy) {
    Copy-Item -LiteralPath $resource.FullName -Destination $stagingPath -Recurse -Force
}

$companionAssetDestinationPath = Join-Path `
    $stagingPath `
    "Resources\CompanionAssets"
New-Item -ItemType Directory -Path $companionAssetDestinationPath -Force | Out-Null
Get-ChildItem -LiteralPath $companionAssetSourcePath -Force |
    ForEach-Object {
        Copy-Item `
            -LiteralPath $_.FullName `
            -Destination $companionAssetDestinationPath `
            -Recurse `
            -Force
    }
& (Join-Path $projectDirectory "Scripts\validate_windows_companion_assets.ps1") `
    -AssetRoot $companionAssetDestinationPath

@"
Tokeni Bar for Windows
Version: $Version

Run TokeniWindows.exe to start the portable application.
Companion sprites are included under Resources\CompanionAssets.
This artifact is unsigned and does not register an installer or automatic update.
"@ | Set-Content -LiteralPath (Join-Path $stagingPath 'README.txt') -Encoding utf8

Compress-Archive -Path (Join-Path $stagingPath '*') `
    -DestinationPath $archivePath `
    -CompressionLevel Optimal

$archiveHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumLine = "$archiveHash  $([System.IO.Path]::GetFileName($archivePath))`n"
$checksumEncoding = [System.Text.UTF8Encoding]::new($false)
[System.IO.File]::WriteAllText($checksumPath, $checksumLine, $checksumEncoding)

Write-Output $archivePath
