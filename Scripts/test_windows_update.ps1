Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\packaging\windows\Update-TokeniBar.ps1') -LibraryOnly
Assert-ReleaseIdentity '1.2.3' 'v1.2.3'
foreach ($invalid in @(@('1.2.3','../evil'),@('1.2.3','v9.0.0'),@('1.2.3-preview','v1.2.3-preview'))) {
    $rejected = $false
    try { Assert-ReleaseIdentity $invalid[0] $invalid[1] } catch { $rejected = $true }
    if (-not $rejected) { throw 'Unsafe release was accepted.' }
}
$scratch = Join-Path $env:TEMP ('Tokeni-Update-Test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    $unsigned = Join-Path $scratch 'unsigned.exe'
    Set-Content -LiteralPath $unsigned -Value 'untrusted executable'
    $rejected = $false
    try { Assert-SignedPublisher $unsigned '' } catch { $rejected = $true }
    if (-not $rejected) { throw 'Unsigned update accepted.' }
    $app = Join-Path $scratch 'app'; $backup = Join-Path $scratch 'backup'; $failed = Join-Path $scratch 'failed'
    New-Item -ItemType Directory -Path $app,$backup | Out-Null
    Set-Content -LiteralPath (Join-Path $app 'TokeniWindows.exe') -Value 'failed version'
    Set-Content -LiteralPath (Join-Path $backup 'TokeniWindows.exe') -Value 'working version'
    Set-Content -LiteralPath (Join-Path $backup 'preserved.txt') -Value 'user-added file'
    Restore-Installation $app $backup $failed
    if ((Get-Content -LiteralPath (Join-Path $app 'TokeniWindows.exe')) -ne 'working version') { throw 'Rollback failed.' }
    if (-not (Test-Path -LiteralPath (Join-Path $app 'preserved.txt'))) { throw 'Rollback lost a file.' }
    Write-Output 'TOKENI_WINDOWS_UPDATE_OK release identity unsigned rejection rollback'
} finally {
    $resolved = [IO.Path]::GetFullPath($scratch)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\Tokeni-Update-Test-', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
