[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$Version,
    [Parameter(Mandatory)][string]$PackageDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [string]$Compiler = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$package = (Resolve-Path -LiteralPath $PackageDirectory).Path
$output = [IO.Path]::GetFullPath($OutputDirectory)
if (-not (Test-Path -LiteralPath (Join-Path $package 'TokeniWindows.exe'))) { throw 'Package executable missing.' }
if (-not (Test-Path -LiteralPath $Compiler)) { throw 'Install Inno Setup 6 or supply -Compiler with the ISCC.exe path.' }
New-Item -ItemType Directory -Path $output -Force | Out-Null
& $Compiler "/DAppVersion=$Version" "/DPackageDirectory=$package" "/DInstallerOutput=$output" (Join-Path $PSScriptRoot '..\packaging\windows\TokeniBar.iss')
if ($LASTEXITCODE -ne 0) { throw 'Windows installer compilation failed.' }
$installer = Join-Path $output "Tokeni-Bar-Windows-$Version-Setup.exe"
$hash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash.ToLowerInvariant()
"$hash  $([IO.Path]::GetFileName($installer))" | Set-Content -LiteralPath "$installer.sha256" -Encoding ascii
Write-Output $installer
