# Runs every brave-and-cold/tests/test_*.gd headless, one at a time (never in parallel).
# Result per suite: exit code, FAIL/SCRIPT ERROR/Parse Error counts. Summary -> shots/script_tests.txt
# Usage: powershell -File tools\run_script_tests.ps1 [-Only test_jump,test_survival] [-TimeoutS 400]
param([string[]]$Only = @(), [int]$TimeoutS = 600)  # test_walk_surfaces needs ~385 s
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })   # -File passes "a,b" as one string
$g = 'C:\Users\parst\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$root = Split-Path $PSScriptRoot -Parent
$P = Join-Path $root 'brave-and-cold'
$S = Join-Path $root 'shots\script_tests'
New-Item -ItemType Directory -Force $S | Out-Null
$sum = Join-Path $root 'shots\script_tests.txt'
Remove-Item $sum -ea 0
$tests = Get-ChildItem (Join-Path $P 'tests') -Filter 'test_*.gd' | Sort-Object Name
foreach ($t in $tests) {
  $n = $t.BaseName
  if ($Only.Count -gt 0 -and $Only -notcontains $n) { continue }
  $log = Join-Path $S "$n.log"; $err = Join-Path $S "$n.err"
  $t0 = Get-Date
  $pr = Start-Process $g -ArgumentList @('--headless', '--path', $P, '--script', "res://tests/$($t.Name)") -RedirectStandardOutput $log -RedirectStandardError $err -PassThru
  if (-not $pr.WaitForExit($TimeoutS * 1000)) {
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $pr.Id } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ea 0 }
    Stop-Process -Id $pr.Id -Force -ea 0; $code = 'TIMEOUT'
  } else { $code = $pr.ExitCode }
  $all = @(Get-Content $log, $err -ea 0)
  $fails = @($all | Select-String -Pattern '\bFAIL' -CaseSensitive).Count
  $errs = @($all | Select-String -Pattern 'SCRIPT ERROR|Parse Error' -CaseSensitive).Count
  $secs = [int]((Get-Date) - $t0).TotalSeconds
  $line = '{0,-34} exit={1,-7} FAIL={2,-3} SCRIPT_ERR={3,-3} {4}s' -f $n, $code, $fails, $errs, $secs
  Add-Content $sum $line
}
Add-Content $sum 'done'
