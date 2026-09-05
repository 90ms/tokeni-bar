[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Version,

    [Parameter(Mandatory = $true)]
    [string] $BuildDirectory,

    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string] $SQLiteExecutable,

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
$sqliteExecutablePath = Resolve-InputPath $SQLiteExecutable
Assert-SafeOutputDirectory $outputPath

if (-not (Test-Path -LiteralPath $buildPath -PathType Container)) {
    throw "Build directory does not exist: $buildPath"
}

$binaryPath = Join-Path $buildPath "TokeniWindows.exe"
if (-not (Test-Path -LiteralPath $binaryPath -PathType Leaf)) {
    throw "TokeniWindows.exe was not found in: $buildPath"
}
if (-not (Test-Path -LiteralPath $sqliteExecutablePath -PathType Leaf) -or
    [System.IO.Path]::GetFileName($sqliteExecutablePath) -cne "sqlite3.exe") {
    throw "The pinned sqlite3.exe was not found: $sqliteExecutablePath"
}
$sqliteManifestPath = Join-Path `
    $projectDirectory `
    "packaging\windows\sqlite-tools.json"
$sqliteManifest = Get-Content -LiteralPath $sqliteManifestPath -Raw |
    ConvertFrom-Json
$sqliteHash = Get-FileHash `
    -LiteralPath $sqliteExecutablePath `
    -Algorithm SHA256
if ($sqliteHash.Hash.ToLowerInvariant() -ne
    $sqliteManifest.executable_sha256) {
    throw "The supplied sqlite3.exe does not match the pinned manifest."
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
& (Join-Path $PSScriptRoot 'set_windows_icon.ps1') -Executable (Join-Path $stagingPath 'TokeniWindows.exe') -IconPath (Join-Path $stagingPath 'TokeniBar.ico')

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

$toolsPath = Join-Path $stagingPath "Tools"
New-Item -ItemType Directory -Path $toolsPath -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $projectDirectory 'packaging\windows\Update-TokeniBar.ps1') -Destination $toolsPath
@{ version = $Version; repository = '90ms/tokeni-bar' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stagingPath 'version.json') -Encoding utf8
Copy-Item `
    -LiteralPath $sqliteExecutablePath `
    -Destination (Join-Path $toolsPath "sqlite3.exe") `
    -Force
Copy-Item `
    -LiteralPath $sqliteManifestPath `
    -Destination $toolsPath `
    -Force
Copy-Item `
    -LiteralPath (Join-Path $projectDirectory "packaging\windows\THIRD-PARTY-NOTICES.txt") `
    -Destination $stagingPath `
    -Force

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
The pinned SQLite CLI is included under Tools\sqlite3.exe.
Its immutable acquisition manifest is included under Tools\sqlite-tools.json.
Third-party provenance is recorded in THIRD-PARTY-NOTICES.txt.
Release artifacts are signed after staging. Development artifacts may remain unsigned.
Use the separate Setup.exe for Start menu integration and verified in-app updates.
Portable installations can check releases and be replaced manually.
"@ | Set-Content -LiteralPath (Join-Path $stagingPath 'README.txt') -Encoding utf8

& (Join-Path $PSScriptRoot "write_windows_package.ps1") `
    -Version $Version `
    -OutputDirectory $outputPath
