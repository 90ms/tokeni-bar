[CmdletBinding()]
param([Parameter(Mandatory)][string]$Executable)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Join-Path $env:TEMP ('Tokeni-Desktop-Test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
$start=[Diagnostics.ProcessStartInfo]::new((Resolve-Path -LiteralPath $Executable).Path)
$start.UseShellExecute=$false
$start.CreateNoWindow=$true
$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
$start.Arguments='--desktop-smoke-test --background'
$start.RedirectStandardOutput=$true
$start.RedirectStandardError=$true
$start.Environment['APPDATA']=Join-Path $root 'Roaming'
$start.Environment['LOCALAPPDATA']=Join-Path $root 'Local'
$process=[Diagnostics.Process]::new()
$process.StartInfo=$start
try {
    if(-not $process.Start()){throw 'Desktop host did not start.'}
    $stdout=$process.StandardOutput.ReadToEndAsync()
    $stderr=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit(25000)){ $process.Kill();$process.WaitForExit();throw 'Desktop host did not publish data and exit within its deadline.' }
    $output=$stdout.GetAwaiter().GetResult()
    $errors=$stderr.GetAwaiter().GetResult()
    if($process.ExitCode -ne 0 -or $output -notmatch 'TOKENI_WINDOWS_DESKTOP_SMOKE_OK'){throw "Desktop host test failed ($($process.ExitCode)): $output $errors"}
    Write-Output 'TOKENI_WINDOWS_DESKTOP_HOST_OK live Swift publication and shutdown'
} finally {
    $process.Dispose()
    $resolved=[IO.Path]::GetFullPath($root)
    if(-not $resolved.StartsWith([IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\Tokeni-Desktop-Test-',[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe desktop-test cleanup.'}
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
