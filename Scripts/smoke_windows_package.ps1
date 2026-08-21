[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $ArchivePath,

    [ValidateRange(1, 120)]
    [int] $TimeoutSeconds = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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

$process = $null
try {
    New-Item -ItemType Directory -Path $temporaryRoot | Out-Null
    Expand-Archive -LiteralPath $resolvedArchive -DestinationPath $temporaryRoot

    $executable = Join-Path $temporaryRoot "TokeniWindows.exe"
    $readme = Join-Path $temporaryRoot "README.txt"
    $manifest = Join-Path `
        $temporaryRoot `
        "Resources\CompanionAssets\bytebot\manifest.json"
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Unpacked package does not contain TokeniWindows.exe."
    }
    if (-not (Test-Path -LiteralPath $readme -PathType Leaf)) {
        throw "Unpacked package does not contain README.txt."
    }
    if (-not (Test-Path -LiteralPath $manifest -PathType Leaf)) {
        throw "Unpacked package does not contain the companion manifest."
    }
    $runtimeDLLs = @(Get-ChildItem -LiteralPath $temporaryRoot -Filter "*.dll" -File)
    if ($runtimeDLLs.Count -eq 0) {
        throw "Unpacked package does not contain runtime DLLs."
    }

    $standardOutputPath = Join-Path $temporaryRoot "smoke-stdout.txt"
    $standardErrorPath = Join-Path $temporaryRoot "smoke-stderr.txt"
    $process = Start-Process `
        -FilePath $executable `
        -ArgumentList "--smoke-test" `
        -WorkingDirectory $temporaryRoot `
        -NoNewWindow `
        -PassThru `
        -RedirectStandardOutput $standardOutputPath `
        -RedirectStandardError $standardErrorPath

    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit()
        throw "Packaged Windows smoke test timed out after $TimeoutSeconds seconds."
    }

    $standardOutput = Get-Content -LiteralPath $standardOutputPath -Raw
    $standardError = Get-Content -LiteralPath $standardErrorPath -Raw
    if ($process.ExitCode -ne 0) {
        throw "Packaged Windows smoke test exited $($process.ExitCode). stderr: $standardError"
    }
    if ($standardOutput -notmatch '(?m)^TOKENI_WINDOWS_SMOKE_OK assets=bytebot presentation=75\s*$') {
        throw "Packaged Windows smoke test did not emit its success marker. stdout: $standardOutput"
    }

    Write-Output "Packaged Windows smoke test passed."
}
finally {
    if ($null -ne $process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        $process.WaitForExit()
    }
    if (Test-Path -LiteralPath $temporaryRoot) {
        Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
    }
}
