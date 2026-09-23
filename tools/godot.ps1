<#
.SYNOPSIS
  Thin wrapper around the Godot mono editor executable (not on PATH).

.EXAMPLE
  powershell -File tools/godot.ps1 --headless --path the-brave-and-the-cold --import
  powershell -File tools/godot.ps1 --path the-brave-and-the-cold
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$GodotArgs
)

$GodotExe = 'C:\Users\parst\Downloads\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64.exe'

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot executable not found: $GodotExe"
}

& $GodotExe $GodotArgs
exit $LASTEXITCODE
