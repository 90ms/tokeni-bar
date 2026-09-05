[CmdletBinding()]
param([Parameter(Mandatory)][string]$Executable, [Parameter(Mandatory)][string]$IconPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('TokeniPackaging.IconResource' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace TokeniPackaging {
 public static class IconResource {
  [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr BeginUpdateResource(string path, bool delete);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool UpdateResource(IntPtr handle, IntPtr type, IntPtr name, ushort language, byte[] data, uint size);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool EndUpdateResource(IntPtr handle, bool discard);
 }
}
'@
}
$source = [Drawing.Image]::FromFile((Join-Path $PSScriptRoot '..\packaging\AppIcon.png'))
$images = @()
try {
    foreach ($dimension in @(16,24,32,48,64,128,256)) {
        $bitmap = [Drawing.Bitmap]::new($dimension,$dimension)
        $graphics = [Drawing.Graphics]::FromImage($bitmap)
        $stream = [IO.MemoryStream]::new()
        try {
            $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($source,0,0,$dimension,$dimension)
            $bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png)
            $images += @{dimension=$dimension;data=$stream.ToArray()}
        } finally { $stream.Dispose();$graphics.Dispose();$bitmap.Dispose() }
    }
} finally { $source.Dispose() }
$icon = [IO.MemoryStream]::new();$writer = [IO.BinaryWriter]::new($icon)
$group = [IO.MemoryStream]::new();$groupWriter = [IO.BinaryWriter]::new($group)
foreach ($binaryWriter in @($writer,$groupWriter)) { $binaryWriter.Write([uint16]0);$binaryWriter.Write([uint16]1);$binaryWriter.Write([uint16]$images.Count) }
$offset = 6 + 16 * $images.Count
for ($index=0; $index -lt $images.Count; $index++) {
    $item = $images[$index];$dimension = [byte]($item.dimension % 256)
    foreach ($binaryWriter in @($writer,$groupWriter)) {
        $binaryWriter.Write($dimension);$binaryWriter.Write($dimension);$binaryWriter.Write([byte]0);$binaryWriter.Write([byte]0)
        $binaryWriter.Write([uint16]1);$binaryWriter.Write([uint16]32);$binaryWriter.Write([uint32]$item.data.Length)
    }
    $writer.Write([uint32]$offset);$groupWriter.Write([uint16]($index+1));$offset += $item.data.Length
}
foreach ($item in $images) { $writer.Write([byte[]]$item.data) }
[IO.File]::WriteAllBytes([IO.Path]::GetFullPath($IconPath),$icon.ToArray())
$handle = [TokeniPackaging.IconResource]::BeginUpdateResource([IO.Path]::GetFullPath($Executable),$false)
if ($handle -eq [IntPtr]::Zero) { throw 'Could not open executable resources.' }
$complete = $false
try {
    for ($index=0; $index -lt $images.Count; $index++) {
        [byte[]]$bytes = $images[$index].data
        if (-not [TokeniPackaging.IconResource]::UpdateResource($handle,[IntPtr]3,[IntPtr]($index+1),0,$bytes,$bytes.Length)) { throw 'Could not write icon resource.' }
    }
    [byte[]]$bytes = $group.ToArray()
    if (-not [TokeniPackaging.IconResource]::UpdateResource($handle,[IntPtr]14,[IntPtr]101,0,$bytes,$bytes.Length)) { throw 'Could not write icon group.' }
    $complete = $true
} finally {
    $saved = [TokeniPackaging.IconResource]::EndUpdateResource($handle,(-not $complete))
    $writer.Dispose();$icon.Dispose();$groupWriter.Dispose();$group.Dispose()
    if ($complete -and -not $saved) { throw 'Could not save executable icon.' }
}
