[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $AssetRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedAssetRoot = [System.IO.Path]::GetFullPath($AssetRoot)
$expectedSpecies = @(
    "bytebot",
    "cachecat",
    "stackfox",
    "promptpup",
    "nullslime",
    "queryowl",
    "patchpanda",
    "loophare",
    "relayray",
    "kernelcrab"
)
$expectedBehaviors = @(
    "idle",
    "working",
    "waiting",
    "warning",
    "celebrate",
    "signature",
    "sleep"
)

function Fail-Validation {
    param([string] $Message)
    throw "Windows companion asset validation failed: $Message"
}

function Read-BigEndianUInt32 {
    param(
        [byte[]] $Bytes,
        [int] $Offset
    )

    return ([uint32]$Bytes[$Offset] -shl 24) -bor
        ([uint32]$Bytes[$Offset + 1] -shl 16) -bor
        ([uint32]$Bytes[$Offset + 2] -shl 8) -bor
        [uint32]$Bytes[$Offset + 3]
}

if (-not (Test-Path -LiteralPath $resolvedAssetRoot -PathType Container)) {
    Fail-Validation "asset root does not exist: $resolvedAssetRoot"
}

foreach ($species in $expectedSpecies) {
    $speciesDirectory = Join-Path $resolvedAssetRoot $species
    if (-not (Test-Path -LiteralPath $speciesDirectory -PathType Container)) {
        Fail-Validation "missing species directory: $species"
    }

    $manifestPath = Join-Path $speciesDirectory "manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        Fail-Validation "missing manifest: $species"
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.schemaVersion -ne 2) {
        Fail-Validation "$species manifest schemaVersion is not 2"
    }
    if ($manifest.id -ne $species) {
        Fail-Validation "$species manifest has id $($manifest.id)"
    }
    if ($manifest.columns -ne 8 -or $manifest.rows -ne 6) {
        Fail-Validation "$species manifest does not describe an 8x6 sheet"
    }

    $manifestBehaviors = @($manifest.animations.PSObject.Properties.Name)
    foreach ($behavior in $expectedBehaviors) {
        if ($manifestBehaviors -notcontains $behavior) {
            Fail-Validation "$species manifest is missing $behavior animation"
        }
    }

    $referencedFiles = @(
        $manifest.forms.PSObject.Properties |
            ForEach-Object { [string]$_.Value } |
            Sort-Object -Unique
    )
    if ($referencedFiles.Count -eq 0) {
        Fail-Validation "$species manifest references no sprite sheets"
    }
    $expectedReferenceCount = if ($species -eq "bytebot") { 7 } else { 6 }
    if ($referencedFiles.Count -ne $expectedReferenceCount) {
        Fail-Validation "$species references $($referencedFiles.Count) sheets; expected $expectedReferenceCount"
    }

    foreach ($fileName in $referencedFiles) {
        if ([System.IO.Path]::GetExtension($fileName) -ne ".png") {
            Fail-Validation "$species manifest references a non-PNG file: $fileName"
        }
        $spritePath = Join-Path $speciesDirectory $fileName
        if (-not (Test-Path -LiteralPath $spritePath -PathType Leaf)) {
            Fail-Validation "$species is missing $fileName"
        }
        $bytes = [System.IO.File]::ReadAllBytes($spritePath)
        if ($bytes.Length -lt 24 -or
            $bytes[0] -ne 137 -or $bytes[1] -ne 80 -or
            $bytes[2] -ne 78 -or $bytes[3] -ne 71 -or
            $bytes[4] -ne 13 -or $bytes[5] -ne 10 -or
            $bytes[6] -ne 26 -or $bytes[7] -ne 10)
        {
            Fail-Validation "$species/$fileName is not a PNG"
        }
        $width = Read-BigEndianUInt32 -Bytes $bytes -Offset 16
        $height = Read-BigEndianUInt32 -Bytes $bytes -Offset 20
        if ($width -ne 512 -or $height -ne 384) {
            Fail-Validation "$species/$fileName is ${width}x${height}; expected 512x384"
        }
    }
}

Write-Output "Validated $($expectedSpecies.Count) Windows companion asset sets at $resolvedAssetRoot."
