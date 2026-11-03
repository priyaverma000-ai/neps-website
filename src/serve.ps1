# Local preview at http://localhost:8765/. Like GitHub Pages, /admissions also serves admissions.html
# and missing pages get 404.html. Run: powershell -File src\serve.ps1
$root=Split-Path $PSScriptRoot -Parent
$l=New-Object Net.HttpListener; $l.Prefixes.Add('http://localhost:8765/'); $l.Start(); "serving $root on 8765"
$types=@{'.html'='text/html; charset=utf-8';'.css'='text/css';'.js'='text/javascript';'.jpg'='image/jpeg';'.png'='image/png';'.mp4'='video/mp4';'.pdf'='application/pdf';'.xml'='application/xml';'.txt'='text/plain'}
while($l.IsListening){ $c=$l.GetContext(); try{
  $p=[Uri]::UnescapeDataString($c.Request.Url.AbsolutePath).TrimStart('/'); if(-not $p){$p='index.html'}
  $f=Join-Path $root $p
  if(-not (Test-Path $f -PathType Leaf) -and (Test-Path "$f.html" -PathType Leaf)){ $f="$f.html" }
  if(-not ((Test-Path $f -PathType Leaf) -and ([IO.Path]::GetFullPath($f)).StartsWith($root))){ $c.Response.StatusCode=404; $f=Join-Path $root '404.html' }
  $c.Response.ContentType=$types[[IO.Path]::GetExtension($f).ToLower()]
  $b=[IO.File]::ReadAllBytes($f); $c.Response.ContentLength64=$b.Length; $c.Response.OutputStream.Write($b,0,$b.Length)
 }catch{} finally{ $c.Response.Close() } }
