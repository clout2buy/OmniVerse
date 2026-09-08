# Cut a release: bump version, run checks, commit, tag, push. CI builds and publishes it.
# Usage:  .\tools\release.ps1 0.2.0
param([Parameter(Mandatory = $true)][string]$Version)

$ErrorActionPreference = "Stop"
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw "Version must look like 1.2.3" }
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

if (git status --porcelain) { throw "Commit or stash your changes first." }

Write-Host "== checks"
& "$root\tools\check.ps1"
if ($LASTEXITCODE -ne 0) { throw "Checks failed; not releasing." }

Write-Host "== bump to $Version"
(Get-Content project.godot) -replace 'config/version="[^"]*"', "config/version=""$Version""" | Set-Content project.godot -Encoding utf8
git add project.godot
git commit -m "Release v$Version"
git tag "v$Version"
git push
git push origin "v$Version"
Write-Host "Pushed v$Version. Watch the build: gh run watch"
