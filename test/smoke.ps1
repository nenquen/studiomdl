# Smoke test for studiomdl (MSVC build output).
# Usage: powershell -ExecutionPolicy Bypass -File test/smoke.ps1 [-Exe <path>] [-WorkDir <path>]
param(
  [string]$Exe = "bin/Release/studiomdl.exe",
  [string]$WorkDir = ""
)

$ErrorActionPreference = "Stop"

function Fail($msg) { Write-Host "FAIL: $msg"; exit 1 }
function Ok($msg) { Write-Host "PASS: $msg" }

$root = Split-Path -Parent $PSScriptRoot
if (-not [IO.Path]::IsPathRooted($Exe)) { $Exe = Join-Path $root $Exe }
if (-not (Test-Path $Exe)) { Fail "exe not found: $Exe" }
Write-Host "Exe: $Exe"

# Python discovery: prefer 'python', fall back to the 'py -3' launcher
# (bare 'python' can resolve to the Microsoft Store stub on some machines).
$script:PyExe = $null
$script:PyArgs = @()
foreach ($cand in @(@{ exe = 'python'; args = @() }, @{ exe = 'py'; args = @('-3') })) {
  try {
    & $cand.exe $cand.args --version
    if ($LASTEXITCODE -eq 0) {
      $script:PyExe = $cand.exe
      $script:PyArgs = $cand.args
      break
    }
  } catch { }
}
if (-not $script:PyExe) { Fail "no working python found (tried 'python', 'py -3'). PATH=$env:PATH" }

if ($WorkDir -eq "") {
  $WorkDir = Join-Path ([IO.Path]::GetTempPath()) ("mdlcc-test-" + [Guid]::NewGuid().ToString("N"))
}
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
Write-Host "WorkDir: $WorkDir"

function Assert-Mdl($mdl) {
  if (-not (Test-Path $mdl)) { Fail "missing $mdl" }
  $b = [IO.File]::ReadAllBytes($mdl)
  if ($b.Length -lt 8) { Fail "$mdl too small" }
  $magic = [Text.Encoding]::ASCII.GetString($b[0..3])
  $ver = [BitConverter]::ToInt32($b, 4)
  if ($magic -ne "IDST" -or $ver -ne 10) { Fail "$mdl bad header: magic=$magic ver=$ver" }
}

try {
  $gen = Join-Path $root "testdata/gen_qc.py"
  $d1 = Join-Path $WorkDir "m1"; $d2 = Join-Path $WorkDir "m2"
  New-Item -ItemType Directory -Force -Path $d1, $d2 | Out-Null

  & $script:PyExe $script:PyArgs $gen $d1
  if ($LASTEXITCODE -ne 0) { Fail "gen_qc.py failed" }
  Copy-Item (Join-Path $d1 "*") $d2

  # 1. Single-file compile, output must land next to the QC.
  & $Exe -nopause (Join-Path $d1 "test.qc")
  if ($LASTEXITCODE -ne 0) { Fail "single compile exit=$LASTEXITCODE" }
  Assert-Mdl (Join-Path $d1 "test.mdl")
  Ok "single-file compile"

  # 2. Flags still work.
  Remove-Item (Join-Path $d1 "test.mdl")
  & $Exe -nopause -f (Join-Path $d1 "test.qc")
  if ($LASTEXITCODE -ne 0) { Fail "-f compile exit=$LASTEXITCODE" }
  Assert-Mdl (Join-Path $d1 "test.mdl")
  Ok "flag compile"

  # 3. Multi-file drag-and-drop mode.
  & $Exe -nopause (Join-Path $d1 "test.qc"), (Join-Path $d2 "test.qc")
  if ($LASTEXITCODE -ne 0) { Fail "multi compile exit=$LASTEXITCODE" }
  Assert-Mdl (Join-Path $d1 "test.mdl")
  Assert-Mdl (Join-Path $d2 "test.mdl")
  Ok "multi-file compile"

  # 4. No args prints usage and fails (stdin closed so no hang).
  '' | & $Exe | Out-Null
  if ($LASTEXITCODE -eq 0) { Fail "no-args should fail non-zero" }
  Ok "usage mode"

  # 5. Invalid input must fail non-zero (and not hang: -nopause).
  $bad = Join-Path $WorkDir "bad.qc"
  [IO.File]::WriteAllText($bad, "this is not a qc file")
  & $Exe -nopause $bad | Out-Null
  if ($LASTEXITCODE -eq 0) { Fail "invalid input should fail non-zero" }
  Ok "invalid input fails cleanly"

  Write-Host "ALL SMOKE TESTS PASSED"
}
finally {
  Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
}
