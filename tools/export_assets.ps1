<#
.SYNOPSIS
  Batch-exports every .blend under assets_src/models to a mirrored .glb path
  inside the Godot project. Incremental: only re-exports when the .blend is
  newer than the existing .glb (use -Force to rebuild everything).

.EXAMPLE
  powershell -File tools/export_assets.ps1
  powershell -File tools/export_assets.ps1 -Force
#>
[CmdletBinding()]
param(
    [string]$BlenderExe = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe",
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$toolsDir = $PSScriptRoot
$root     = Split-Path -Parent $toolsDir
$srcRoot  = Join-Path $root 'assets_src\models'
$dstRoot  = Join-Path $root 'the-brave-and-the-cold\assets\art\models'
$exporter = Join-Path $toolsDir 'blender_export_glb.py'

if (-not (Test-Path -LiteralPath $BlenderExe)) {
    throw "Blender not found at '$BlenderExe'. Pass -BlenderExe with the correct path."
}
if (-not (Test-Path -LiteralPath $srcRoot)) {
    throw "Source folder not found: $srcRoot"
}

$blends = Get-ChildItem -Path $srcRoot -Recurse -Filter '*.blend'
if (-not $blends) {
    Write-Host "No .blend files found under $srcRoot"
    exit 0
}

$exported = 0
foreach ($blend in $blends) {
    $rel    = $blend.FullName.Substring($srcRoot.Length).TrimStart('\')
    $dst    = Join-Path $dstRoot ([IO.Path]::ChangeExtension($rel, '.glb'))
    $dstDir = Split-Path -Parent $dst

    if (-not (Test-Path -LiteralPath $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }

    if (-not $Force -and (Test-Path -LiteralPath $dst) -and
        (Get-Item -LiteralPath $dst).LastWriteTime -ge $blend.LastWriteTime) {
        Write-Host "SKIP   $rel (up to date)"
        continue
    }

    Write-Host "EXPORT $rel"
    & $BlenderExe --background --python $exporter -- $blend.FullName $dst
    if ($LASTEXITCODE -ne 0) {
        throw "Blender export failed for '$rel' (exit code $LASTEXITCODE)."
    }
    $exported++
}

Write-Host "Done. $exported file(s) exported."
