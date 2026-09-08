# Full headless check: regenerate placeholder models (optional), import, run tests.
# Usage:  .\tools\check.ps1            (import + tests)
#         .\tools\check.ps1 -Models    (also regenerate .glb placeholders with Blender)
param([switch]$Models)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$godot = $env:GODOT
if (-not $godot) { $godot = "C:\Users\Clout\OneDrive\Desktop\Installers & Archives\Godot_v4.7.1\Godot_v4.7.1-stable_win64_console.exe" }
$blender = $env:BLENDER
if (-not $blender) { $blender = "C:\Program Files\Blender Foundation\Blender 5.1\blender.exe" }

if ($Models) {
    Write-Host "== Blender: generating placeholder models"
    & $blender -b --factory-startup -P tools/blender/gen_placeholders.py
    if ($LASTEXITCODE -ne 0) { Write-Host "Blender failed"; exit 1 }
    & $blender -b --factory-startup -P tools/blender/gen_human.py
    if ($LASTEXITCODE -ne 0) { Write-Host "Blender failed"; exit 1 }
}

Write-Host "== Godot: import"
& $godot --headless --path . --import
Write-Host "== Godot: tests"
& $godot --headless --path . -s tests/run_tests.gd
$tests = $LASTEXITCODE
Write-Host "== Godot: smoke run (host solo for 180 frames)"
$out = & $godot --headless --path . --quit-after 180 -- --solo 2>&1 | Out-String
$out
if ($out -cmatch "SCRIPT ERROR|^ERROR:|A Thread object is being destroyed") { Write-Host "Smoke run produced errors"; exit 1 }
exit $tests
