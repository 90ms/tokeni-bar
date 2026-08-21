[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ArchivePath,

    [ValidateRange(1, 120)]
    [int] $TimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-SmokeProcess {
    param(
        [string] $Executable,
        [string[]] $Arguments,
        [string] $WorkingDirectory,
        [int] $Timeout
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $Executable
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $started = $false
    try {
        if (-not $process.Start()) {
            throw "Smoke process could not start: $Executable"
        }
        $started = $true
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($Timeout * 1000)) {
            $process.Kill()
            $process.WaitForExit()
            throw "Smoke process timed out after $Timeout seconds: $Executable"
        }
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StandardOutput = $stdoutTask.GetAwaiter().GetResult()
            StandardError = $stderrTask.GetAwaiter().GetResult()
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

$resolvedArchive = [System.IO.Path]::GetFullPath($ArchivePath)
if (-not (Test-Path -LiteralPath $resolvedArchive -PathType Leaf)) {
    throw "Windows package archive does not exist: $resolvedArchive"
}
if ([System.IO.Path]::GetExtension($resolvedArchive) -ne ".zip") {
    throw "Windows package smoke test requires a ZIP archive: $resolvedArchive"
}

$temporaryRoot = [System.IO.Path]::GetFullPath((Join-Path `
    ([System.IO.Path]::GetTempPath()) `
    "tokeni-windows-package-smoke-$([guid]::NewGuid().ToString('N'))"))
$expectedTemporaryParent = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar)
$actualTemporaryParent = [System.IO.Path]::GetDirectoryName(
    $temporaryRoot).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
if (-not [System.String]::Equals(
        $actualTemporaryParent,
        $expectedTemporaryParent,
        [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing unexpected smoke-test directory: $temporaryRoot"
}

try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    Expand-Archive -LiteralPath $resolvedArchive -DestinationPath $temporaryRoot

    $executable = Join-Path $temporaryRoot "TokeniWindows.exe"
    $readme = Join-Path $temporaryRoot "README.txt"
    $manifest = Join-Path `
        $temporaryRoot `
        "Resources\CompanionAssets\bytebot\manifest.json"
    $sqlite = Join-Path $temporaryRoot "Tools\sqlite3.exe"
    $sqliteManifest = Join-Path $temporaryRoot "Tools\sqlite-tools.json"
    $thirdPartyNotices = Join-Path $temporaryRoot "THIRD-PARTY-NOTICES.txt"
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Unpacked package does not contain TokeniWindows.exe."
    }
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        throw "Unpacked package does not contain README.txt."
    }
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Unpacked package does not contain the companion manifest."
    }
    if (-not (Test-Path -LiteralPath $sqlite -PathType Leaf)) {
        throw "Unpacked package does not contain Tools\sqlite3.exe."
    }
    if (-not (Test-Path -LiteralPath $sqliteManifest -PathType Leaf)) {
        throw "Unpacked package does not contain Tools\sqlite-tools.json."
    }
    if (-not (Test-Path -LiteralPath $thirdPartyNotices -PathType Leaf)) {
        throw "Unpacked package does not contain THIRD-PARTY-NOTICES.txt."
    }
    $runtimeDLLs = @(Get-ChildItem -LiteralPath $temporaryRoot -Filter "*.dll" -File)
    if ($runtimeDLLs.Count -eq 0) {
        throw "Unpacked package does not contain runtime DLLs."
    }

    $sqliteMetadata = Get-Content -LiteralPath $sqliteManifest -Raw |
        ConvertFrom-Json
    $sqliteFileHash = Get-FileHash -LiteralPath $sqlite -Algorithm SHA256
    $sqliteHash = $sqliteFileHash.Hash.ToLowerInvariant()
    if ($sqliteHash -ne $sqliteMetadata.executable_sha256) {
        throw "Packaged SQLite executable does not match its pinned manifest."
    }

    $database = Join-Path $temporaryRoot "sqlite-smoke.db"
    $create = Invoke-SmokeProcess `
        -Executable $sqlite `
        -Arguments @(
            "-batch", "-init", "NUL", $database,
            "CREATE TABLE smoke(value INTEGER); INSERT INTO smoke VALUES(7);") `
        -WorkingDirectory $temporaryRoot `
        -Timeout $TimeoutSeconds
    if ($create.ExitCode -ne 0) {
        throw "Packaged SQLite setup failed: $($create.StandardError)"
    }
    $databaseHashBefore = (Get-FileHash -LiteralPath $database -Algorithm SHA256).Hash
    $query = Invoke-SmokeProcess `
        -Executable $sqlite `
        -Arguments @(
            "-batch", "-init", "NUL", "-readonly", "-json", $database,
            "SELECT value FROM smoke;") `
        -WorkingDirectory $temporaryRoot `
        -Timeout $TimeoutSeconds
    if ($query.ExitCode -ne 0) {
        throw "Packaged SQLite read-only query failed: $($query.StandardError)"
    }
    $rows = @($query.StandardOutput | ConvertFrom-Json)
    $databaseHashAfter = (Get-FileHash -LiteralPath $database -Algorithm SHA256).Hash
    if ($rows.Count -ne 1 -or $rows[0].value -ne 7 -or
        $databaseHashAfter -ne $databaseHashBefore) {
        throw "Packaged SQLite did not complete an unchanged read-only JSON query."
    }

    $application = Invoke-SmokeProcess `
        -Executable $executable `
        -Arguments @("--smoke-test") `
        -WorkingDirectory $temporaryRoot `
        -Timeout $TimeoutSeconds
    if ($application.ExitCode -ne 0) {
        throw "Packaged Windows smoke test exited $($application.ExitCode). stderr: $($application.StandardError)"
    }
    if ($application.StandardOutput -notmatch '(?m)^TOKENI_WINDOWS_SMOKE_OK assets=bytebot presentation=75\s*$') {
        throw "Packaged Windows smoke test did not emit its success marker. stdout: $($application.StandardOutput)"
    }

    Write-Output "Packaged Windows smoke test passed."
}
finally {
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
