[CmdletBinding()]
param(
    [ValidateSet('Prepare','Apply')][string]$Mode = 'Prepare',
    [string]$Version,
    [string]$Tag,
    [string]$ApplicationDirectory,
    [int]$ParentProcessId,
    [string]$WorkDirectory,
    [switch]$LibraryOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-ReleaseIdentity([string]$ReleaseVersion, [string]$ReleaseTag) {
    if ($ReleaseVersion -notmatch '^\d+\.\d+\.\d+$' -or $ReleaseTag -cnotin @($ReleaseVersion, "v$ReleaseVersion")) {
        throw 'Invalid stable release identity.'
    }
}
function Assert-Installation([string]$Directory) {
    $resolved = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    $registered = (Get-ItemProperty -LiteralPath 'HKCU:\Software\TokeniBar\Installation' -Name Directory).Directory
    if (-not [string]::Equals($resolved, [IO.Path]::GetFullPath($registered).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Only the registered per-user installation can update itself.' }
    if ($resolved -eq [IO.Path]::GetPathRoot($resolved).TrimEnd('\') -or -not (Test-Path -LiteralPath (Join-Path $resolved 'unins000.exe'))) { throw 'Invalid installation directory.' }
    $cursor = Get-Item -LiteralPath $resolved
    while ($null -ne $cursor) {
        if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Installation links are unsupported.' }
        $cursor = $cursor.Parent
    }
    if (Get-ChildItem -LiteralPath $resolved -Recurse -Force | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint } | Select-Object -First 1) { throw 'Installation contains links.' }
    return $resolved
}
function Assert-SignedPublisher([string]$Path, [string]$Publisher) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid' -or $null -eq $signature.SignerCertificate) { throw 'A valid trusted Authenticode signature is required.' }
    if ($Publisher -and $signature.SignerCertificate.Subject -cne $Publisher) { throw 'Update publisher does not match the installed application.' }
    return $signature.SignerCertificate.Subject
}
function Assert-UpdateWorkDirectory([string]$Directory) {
    $root = [IO.Path]::GetFullPath((Join-Path $env:LOCALAPPDATA 'TokeniBarUpdate')).TrimEnd('\')
    $resolved = [IO.Path]::GetFullPath($Directory).TrimEnd('\')
    if ([IO.Path]::GetDirectoryName($resolved) -cne $root -or [IO.Path]::GetFileName($resolved) -notmatch '^[a-f0-9]{32}$') { throw 'Invalid update workspace.' }
    $cursor = Get-Item -LiteralPath $resolved
    while ($null -ne $cursor) {
        if ($cursor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Update workspace contains links.' }
        $cursor = $cursor.Parent
    }
    return $resolved
}
function Restore-Installation([string]$Directory, [string]$Backup, [string]$FailedDirectory) {
    # All arguments are fixed children of the validated installation/update workspace.
    if (-not (Test-Path -LiteralPath (Join-Path $Backup 'TokeniWindows.exe'))) { throw 'Rollback backup is incomplete.' }
    if (Test-Path -LiteralPath $Directory) { Move-Item -LiteralPath $Directory -Destination $FailedDirectory }
    Move-Item -LiteralPath $Backup -Destination $Directory
}
if ($LibraryOnly) { return }
Assert-ReleaseIdentity $Version $Tag
$application = Assert-Installation $ApplicationDirectory
$binary = Join-Path $application 'TokeniWindows.exe'
$publisher = Assert-SignedPublisher $binary ''
$current = Get-Content -LiteralPath (Join-Path $application 'version.json') -Raw | ConvertFrom-Json
if ([version]$Version -le [version]$current.version) { throw 'Update must be newer than the installed version.' }
$assetName = "Tokeni-Bar-Windows-$Version-Setup.exe"

if ($Mode -eq 'Prepare') {
    $work = Join-Path (Join-Path $env:LOCALAPPDATA 'TokeniBarUpdate') ([guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $work -Force | Out-Null
    $work = Assert-UpdateWorkDirectory $work
    $installer = Join-Path $work $assetName
    # Both paths are fixed to this project's release and contain validated numeric versions.
    $url = "https://github.com/90ms/tokeni-bar/releases/download/$Tag/$assetName"
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing -TimeoutSec 180
    Invoke-WebRequest -Uri "$url.sha256" -OutFile "$installer.sha256" -UseBasicParsing -TimeoutSec 30
    $checksum = (Get-Content -LiteralPath "$installer.sha256" -Raw).Trim()
    if ($checksum -notmatch ('^([a-fA-F0-9]{64})\s+\*?' + [regex]::Escape($assetName) + '$')) { throw 'Invalid release checksum.' }
    if ((Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash -ine $matches[1]) { throw 'Update checksum mismatch.' }
    $null = Assert-SignedPublisher $installer $publisher
    $worker = Join-Path $work 'Update-TokeniBar.ps1'
    Copy-Item -LiteralPath $PSCommandPath -Destination $worker
    $arguments = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',"`"$worker`"",'-Mode','Apply','-Version',$Version,'-Tag',$Tag,'-ApplicationDirectory',"`"$application`"",'-ParentProcessId',$ParentProcessId,'-WorkDirectory',"`"$work`"")
    Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList $arguments -WindowStyle Hidden | Out-Null
    exit 0
}

$work = Assert-UpdateWorkDirectory $WorkDirectory
$installer = Join-Path $work $assetName
$null = Assert-SignedPublisher $installer $publisher
$backup = Join-Path $work 'backup'
$failed = Join-Path $work 'failed-installation'
$status = Join-Path (Split-Path $work -Parent) 'status.json'
$uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{074D1A56-8482-43A1-A3F8-2FA3C4F30B89}_is1'
$previousRegistration = @{}
if (Test-Path -LiteralPath $uninstallKey) {
    $properties = Get-ItemProperty -LiteralPath $uninstallKey
    foreach ($name in @('DisplayVersion','InstallDate','EstimatedSize','UninstallString','QuietUninstallString')) {
        if ($properties.PSObject.Properties.Name -contains $name) { $previousRegistration[$name] = $properties.$name }
    }
}
try {
    $parent = Get-Process -Id $ParentProcessId -ErrorAction SilentlyContinue
    if ($parent -and -not $parent.WaitForExit(30000)) { throw 'Application did not exit for update.' }
    Copy-Item -LiteralPath $application -Destination $backup -Recurse
    $process = Start-Process $installer -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=`"$application`"") -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(180000)) { throw 'Installer is still running; backup retained for recovery.' }
    if ($process.ExitCode -ne 0) { throw 'Installer failed.' }
    $null = Assert-SignedPublisher $binary $publisher
    $installed = Get-Content -LiteralPath (Join-Path $application 'version.json') -Raw | ConvertFrom-Json
    if ($installed.version -cne $Version) { throw 'Installed version does not match the requested release.' }
    $smoke = Start-Process $binary -ArgumentList '--smoke-test' -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $work 'smoke.stdout.txt') -RedirectStandardError (Join-Path $work 'smoke.stderr.txt')
    if (-not $smoke.WaitForExit(30000)) { Stop-Process -Id $smoke.Id; throw 'Updated application timed out.' }
    if ($smoke.ExitCode -ne 0) { throw 'Updated application failed its runtime check.' }
    @{state='installed';version=$Version} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding utf8
    Start-Process $binary -WindowStyle Hidden
} catch {
    # Never replace files while the installer is still using them.
    if ((-not (Get-Variable process -ErrorAction SilentlyContinue) -or $process.HasExited) -and (Test-Path -LiteralPath (Join-Path $backup 'TokeniWindows.exe'))) {
        Restore-Installation $application $backup $failed
        foreach ($entry in $previousRegistration.GetEnumerator()) {
            Set-ItemProperty -LiteralPath $uninstallKey -Name $entry.Key -Value $entry.Value
        }
        @{state='rolled-back';version=$current.version} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding utf8
        Start-Process $binary -WindowStyle Hidden
    } else {
        @{state='recovery-required';version=$current.version} | ConvertTo-Json | Set-Content -LiteralPath $status -Encoding utf8
    }
    exit 1
}
