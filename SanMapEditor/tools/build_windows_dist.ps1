# Build a portable Windows dist of SanMap Editor.
# - Exports Godot project with embedded .pck into SanMapEditor.exe
# - Copies Enviroment/ next to the exe (terrain preview textures, ~3 GB)
#
# Prerequisites: Godot 4.7.x + matching export templates installed.
# Usage (from repo root or SanMapEditor):
#   powershell -ExecutionPolicy Bypass -File SanMapEditor/tools/build_windows_dist.ps1

$ErrorActionPreference = "Stop"

$GodotExe = $env:GODOT_EXE
if (-not $GodotExe) {
    $candidates = @(
        "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe",
        "D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $GodotExe = $c; break }
    }
}
if (-not $GodotExe -or -not (Test-Path $GodotExe)) {
    throw "Godot executable not found. Set GODOT_EXE to Godot_v4.7.x_win64.exe"
}

$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$RepoRoot = (Resolve-Path (Join-Path $ProjectDir "..")).Path
$DistDir = Join-Path $RepoRoot "dist\SanMapEditor"
$ExePath = Join-Path $DistDir "SanMapEditor.exe"
$EnvSrc = Join-Path $RepoRoot "Enviroment"
if (-not (Test-Path $EnvSrc)) { $EnvSrc = Join-Path $RepoRoot "Environment" }

Write-Host "Godot:   $GodotExe"
Write-Host "Project: $ProjectDir"
Write-Host "Dist:    $DistDir"

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

Write-Host "Exporting Windows Desktop (embed_pck)..."
# Call operator keeps paths with spaces intact. Godot may leave $LASTEXITCODE unset on success.
& $GodotExe --headless --path $ProjectDir --export-release "Windows Desktop" $ExePath
$exportCode = $LASTEXITCODE
if (-not (Test-Path $ExePath)) {
    throw "Export finished but exe missing: $ExePath. Exit code: $exportCode. Install export templates for 4.7.2 (Editor -> Manage Export Templates)."
}
if ($null -ne $exportCode -and $exportCode -ne 0) {
    throw "Godot export failed with exit code $exportCode."
}

$exeSizeMb = [math]::Round((Get-Item $ExePath).Length / 1MB, 1)
Write-Host "Exported $ExePath ($exeSizeMb MB)"

if (Test-Path $EnvSrc) {
    $EnvDst = Join-Path $DistDir "Enviroment"
    Write-Host "Copying terrain textures: $EnvSrc -> $EnvDst"
    Write-Host "(This is ~3 GB and lives NEXT TO the exe, not inside it.)"
    if (Test-Path $EnvDst) {
        Write-Host "Enviroment already present - skipping copy. Delete it to refresh."
    } else {
        Copy-Item -Path $EnvSrc -Destination $EnvDst -Recurse -Force
    }
} else {
    Write-Warning "No Enviroment/ folder found next to the repo. Terrain material previews will be missing until you copy it beside the exe."
}

$readme = @"
SanMap Editor - portable build
==============================

Start: SanMapEditor.exe

Terrain preview textures:
  Place the Sanctuary Enviroment folder next to this exe
  (same folder as SanMapEditor.exe). Without it, maps still edit/save,
  but stratum/skybox previews stay empty.

Maps you create are normal folders (MapName/MapName.sanmap + Textures/).
Copy those into your Sanctuary maps directory to play.
"@
Set-Content -Path (Join-Path $DistDir "README.txt") -Value $readme -Encoding UTF8

Write-Host ""
Write-Host "Done. Portable folder: $DistDir"
Write-Host "Zip that folder to share with others."
