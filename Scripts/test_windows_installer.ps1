[CmdletBinding()]
param([Parameter(Mandatory)][string]$Installer)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$installerPath = (Resolve-Path -LiteralPath $Installer).Path
$sandbox = Join-Path $env:TEMP ('Tokeni-Installer-Test-' + [guid]::NewGuid().ToString('N'))
$destination = Join-Path $sandbox 'App'
$registry = 'HKCU:\Software\TokeniBar\Installation'
if (Test-Path -LiteralPath $registry) { throw 'Run installer tests in a clean account without an installed Tokeni Bar.' }
New-Item -ItemType Directory -Path $sandbox | Out-Null
try {
    $process = Start-Process -FilePath $installerPath -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOICONS',"/DIR=`"$destination`"") -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(120000) -or $process.ExitCode -ne 0) { throw 'Installer failed.' }
    $binary = Join-Path $destination 'TokeniWindows.exe'
    if (-not (Test-Path -LiteralPath $binary)) { throw 'Installed application missing.' }
    $smokeOutput = Join-Path $sandbox 'smoke.stdout.txt'
    $smokeError = Join-Path $sandbox 'smoke.stderr.txt'
    $smoke = Start-Process $binary -ArgumentList '--smoke-test' -WindowStyle Hidden -PassThru -RedirectStandardOutput $smokeOutput -RedirectStandardError $smokeError
    if (-not $smoke.WaitForExit(30000)) { Stop-Process -Id $smoke.Id; throw 'Installed application smoke timed out.' }
    Get-Content -LiteralPath $smokeOutput,$smokeError
    if ($smoke.ExitCode -ne 0) { throw "Installed application smoke failed: $($smoke.ExitCode)." }
    if ((Get-Content -LiteralPath $smokeOutput -Raw) -notmatch 'TOKENI_WINDOWS_SMOKE_OK') { throw 'Installed runtime check returned no success marker.' }
    if (-not (Test-Path -LiteralPath (Join-Path $destination 'version.json'))) { throw 'Installed version metadata missing.' }
    # Repeat installation to exercise upgrade/replacement without touching user data.
    $upgrade = Start-Process -FilePath $installerPath -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART','/NOICONS',"/DIR=`"$destination`"") -WindowStyle Hidden -PassThru
    if (-not $upgrade.WaitForExit(120000) -or $upgrade.ExitCode -ne 0) { throw 'Upgrade failed.' }
    $uninstall = Start-Process (Join-Path $destination 'unins000.exe') -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -WindowStyle Hidden -PassThru
    if (-not $uninstall.WaitForExit(30000) -or $uninstall.ExitCode -ne 0) { throw 'Uninstall failed.' }
    if (Test-Path -LiteralPath $binary) { throw 'Uninstall left the executable.' }
    Write-Output 'TOKENI_WINDOWS_INSTALLER_OK install upgrade smoke uninstall'
} finally {
    # Only this test's unique workspace may be removed.
    $resolved = [IO.Path]::GetFullPath($sandbox)
    if (-not $resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\Tokeni-Installer-Test-', [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup.' }
    Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction SilentlyContinue
}
