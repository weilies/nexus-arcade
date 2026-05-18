# Pre-gzip Godot web exports + patch index.html with client-side decompressor.
# Run after each `godot --export-release Web ...` command.
# Usage: powershell -File ./scripts/gzip-game-exports.ps1
$ErrorActionPreference = "Stop"
$root = Join-Path $PSScriptRoot ".." | Resolve-Path
$games = Join-Path $root "portal/public/games"
if (-not (Test-Path $games)) { throw "Not found: $games" }

# Fetch-interceptor injected before index.js in index.html.
# Fetches .wasm.gz as raw bytes, decompresses via DecompressionStream,
# feeds decompressed stream to WebAssembly.instantiateStreaming.
# No Content-Encoding involved — proxy cannot interfere.
$injection = @'
<script>
(function(){
  var _f=window.fetch;
  window.fetch=function(url,opts){
    if(typeof url==='string'&&url.endsWith('.wasm')){
      return _f(url+'.gz',opts).then(function(r){
        if(!r.ok)return _f(url,opts);
        var ds=new DecompressionStream('gzip');
        return new Response(r.body.pipeThrough(ds),{headers:{'Content-Type':'application/wasm'}});
      }).catch(function(){return _f(url,opts);});
    }
    return _f(url,opts);
  };
})();
</script>
'@

foreach ($d in Get-ChildItem $games -Directory) {
  # --- gzip wasm + pck ---
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

  # --- patch index.html ---
  $html = Join-Path $d.FullName "index.html"
  if (-not (Test-Path $html)) { continue }
  $content = [System.IO.File]::ReadAllText($html)
  $marker  = '<script src="index.js">'
  if ($content.Contains($marker) -and -not $content.Contains('DecompressionStream')) {
    $content = $content.Replace($marker, $injection + $marker)
    [System.IO.File]::WriteAllText($html, $content)
    Write-Host ("{0}/index.html: patched with wasm decompressor" -f $d.Name)
  } elseif ($content.Contains('DecompressionStream')) {
    Write-Host ("{0}/index.html: already patched" -f $d.Name)
  }
}
