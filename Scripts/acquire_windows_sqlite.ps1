[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $OutputDirectory,

    [string] $ManifestPath = (Join-Path $PSScriptRoot `
        "..\packaging\windows\sqlite-tools.json"),

    [ValidateRange(1, 120)]
    [int] $TimeoutSeconds = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-PEMachine {
    param([string] $Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 64) {
            throw "SQLite executable is too small to be a PE file."
        }
        $reader = [System.IO.BinaryReader]::new($stream)
        if ($reader.ReadUInt16() -ne 0x5A4D) {
            throw "SQLite executable does not have an MZ header."
        }
        $stream.Position = 0x3C
        $peOffset = $reader.ReadUInt32()
        if ($peOffset -gt $stream.Length - 6) {
            throw "SQLite executable has an invalid PE header offset."
        }
        $stream.Position = $peOffset
        if ($reader.ReadUInt32() -ne 0x00004550) {
            throw "SQLite executable does not have a PE signature."
        }
        return $reader.ReadUInt16()
    }
    finally {
        $stream.Dispose()
    }
}

function Invoke-VersionCheck {
    param(
        [string] $Executable,
        [string] $ExpectedVersion,
        [int] $Timeout
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.ArgumentList.Add("-version")
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $started = $false
    try {
        if (-not $process.Start()) {
            throw "SQLite version check could not start."
        }
        $started = $true
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Timeout * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "SQLite version check timed out after $Timeout seconds."
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "SQLite version check exited $($process.ExitCode): $stderr"
        }
        if ($stdout -notmatch "^$([regex]::Escape($ExpectedVersion))\s") {
            throw "SQLite version output did not start with $ExpectedVersion."
        }
    }
    finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill()
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}

$resolvedManifest = [System.IO.Path]::GetFullPath($ManifestPath)
if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
    throw "SQLite tools manifest does not exist: $resolvedManifest"
}
$manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
if ($manifest.architecture -ne "x64" -or $manifest.executable -ne "sqlite3.exe") {
    throw "Only the reviewed Windows x64 sqlite3.exe artifact is supported."
}
if ($manifest.archive_url -notmatch '^https://(www\.)?sqlite\.org/') {
    throw "SQLite archive URL must use official sqlite.org HTTPS hosting."
}
if ($manifest.archive_sha256 -notmatch '^[0-9a-f]{64}$' -or
    $manifest.archive_sha3_256 -notmatch '^[0-9a-f]{64}$' -or
    $manifest.executable_sha256 -notmatch '^[0-9a-f]{64}$') {
    throw "SQLite archive digests must be lowercase 256-bit hex values."
}

$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
$destination = Join-Path $outputPath "sqlite3.exe"
$temporaryRoot = Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    "tokeni-sqlite-acquire-$([guid]::NewGuid().ToString('N'))"
$temporaryRoot = [System.IO.Path]::GetFullPath($temporaryRoot)
$archivePath = Join-Path $temporaryRoot "sqlite-tools.zip"
$extractedPath = Join-Path $temporaryRoot "sqlite3.exe"

try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    Invoke-WebRequest `
        -Uri $manifest.archive_url `
        -OutFile $archivePath `
        -TimeoutSec $TimeoutSeconds

    $archiveHash = Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
    $sha256 = $archiveHash.Hash.ToLowerInvariant()
    if ($sha256 -ne $manifest.archive_sha256) {
        throw "SQLite archive SHA-256 mismatch."
    }
    $sha3Bytes = [System.Security.Cryptography.SHA3_256]::HashData(
        [System.IO.File]::ReadAllBytes($archivePath))
    $sha3 = [System.Convert]::ToHexString($sha3Bytes).ToLowerInvariant()
    if ($sha3 -ne $manifest.archive_sha3_256) {
        throw "SQLite archive official SHA3-256 mismatch."
    }

    Add-Type -AssemblyName System.IO.Compression
    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
        foreach ($entryName in $entryNames) {
            if ([System.IO.Path]::IsPathRooted($entryName) -or
                $entryName.Contains("/") -or
                $entryName.Contains("\") -or
                $entryName -in @(".", "..")) {
                throw "SQLite archive contains an unsafe entry: $entryName"
            }
        }
        $entries = @($archive.Entries | Where-Object {
            $_.FullName -ceq $manifest.executable
        })
        if ($entries.Count -ne 1) {
            throw "SQLite archive must contain exactly one sqlite3.exe."
        }
        $source = $entries[0].Open()
        $target = [System.IO.File]::Create($extractedPath)
        try {
            $source.CopyTo($target)
        }
        finally {
            $target.Dispose()
            $source.Dispose()
        }
    }
    finally {
        $archive.Dispose()
    }

    if ((Get-PEMachine -Path $extractedPath) -ne 0x8664) {
        throw "SQLite executable is not a Windows x64 PE image."
    }
    $executableHash = Get-FileHash `
        -LiteralPath $extractedPath `
        -Algorithm SHA256
    if ($executableHash.Hash.ToLowerInvariant() -ne
        $manifest.executable_sha256) {
        throw "Extracted SQLite executable SHA-256 mismatch."
    }
    Invoke-VersionCheck `
        -Executable $extractedPath `
        -ExpectedVersion $manifest.version `
        -Timeout $TimeoutSeconds
    Copy-Item -LiteralPath $extractedPath -Destination $destination -Force
    Write-Output $destination
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
