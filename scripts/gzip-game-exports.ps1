# Pre-gzip Godot web exports so middleware.ts can serve .gz with
# Content-Encoding: gzip and cut transfer ~75%.
# Run after each `godot --export-release Web ...` command.
# Usage: pwsh ./scripts/gzip-game-exports.ps1
$ErrorActionPreference = "Stop"
$root = Join-Path $PSScriptRoot ".." | Resolve-Path
$games = Join-Path $root "portal/public/games"
if (-not (Test-Path $games)) { throw "Not found: $games" }
foreach ($d in Get-ChildItem $games -Directory) {
  foreach ($name in @("index.wasm","index.pck")) {
    $src = Join-Path $d.FullName $name
    if (-not (Test-Path $src)) { continue }
    $dst = "$src.gz"
    if ((Test-Path $dst) -and ((Get-Item $dst).LastWriteTime -ge (Get-Item $src).LastWriteTime)) {
      continue
    }
    $in  = [System.IO.File]::OpenRead($src)
    $out = [System.IO.File]::Create($dst)
    $gz  = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionLevel]::Optimal)
    $in.CopyTo($gz)
    $gz.Dispose(); $out.Dispose(); $in.Dispose()
    $raw = [math]::Round((Get-Item $src).Length/1MB,2)
    $g   = [math]::Round((Get-Item $dst).Length/1MB,2)
    Write-Host ("{0}/{1}: {2} MB -> {3} MB" -f $d.Name,$name,$raw,$g)
  }
}
