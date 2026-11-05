# Builds the site: fills each src\tpl page with the shared partials (_head, _header, _footer...)
# and writes the finished page to the site root. Run: powershell -File src\build.ps1
$s= if($args[0]){$args[0]}else{$PSScriptRoot}; $o= if($args[1]){$args[1]}else{Split-Path $PSScriptRoot -Parent}; $t="$s\tpl"
$enc=New-Object Text.UTF8Encoding $false
$site='https://nepsdwarka.com'
function Part($n){ [IO.File]::ReadAllText("$t\_$n.html",$enc) }
function Get-Text($html){ ([Net.WebUtility]::HtmlDecode(($html -replace '<[^>]+>','')) -replace '\s+',' ').Trim() }
function ConvertTo-JsonText($x){ $x | ConvertTo-Json -Depth 8 -Compress }
$h=Part 'header'; $f=Part 'footer'; $head=Part 'head'; $enq=Part 'enquiry'; $calc=Part 'calc'; $nav=Part 'anav'
$pages=Get-ChildItem "$t\*.html" | Where-Object { $_.Name -notlike '_*' }

# First pass: each page's public address, so breadcrumbs and the sitemap can use it
$pathOf=@{'index.html'='/';'blog.html'='/blog/';'blog-post.html'='/blog/why-sports-matter-in-school'}
$sitemap=New-Object Collections.Generic.List[object]
foreach($file in $pages){
  $m=[regex]::Match([IO.File]::ReadAllText($file.FullName,$enc),'^<!--META (.*?)-->')
  if($m.Success){ $v=$m.Groups[1].Value -split '\|\|' | ForEach-Object { $_.Trim() }; $pathOf[$file.Name]=$v[2]; if($v.Count -le 5){ $sitemap.Add(@($v[2],$file)) } }
  elseif($pathOf[$file.Name]){ $sitemap.Add(@($pathOf[$file.Name],$file)) }
}

foreach($file in $pages){
  $p=$file.Name; $c=[IO.File]::ReadAllText($file.FullName,$enc)
  $m=[regex]::Match($c,'^<!--META (.*?)-->\r?\n',[Text.RegularExpressions.RegexOptions]::Singleline)
  if($m.Success){
    # title || description || canonical path || og image || breadcrumb name || optional robots
    $v=$m.Groups[1].Value -split '\|\|' | ForEach-Object { $_.Trim() }
    $url=$site+$v[2]
    # Breadcrumbs come from the page's own visible trail, so Google sees the same path as the reader
    $trail=@(,@('Home',"$site/"))
    $cm=[regex]::Match($c,'<p class="crumbs">(.*?)</p>')
    if($cm.Success){
      foreach($a in [regex]::Matches($cm.Groups[1].Value,'<a href="([^"]+)">(.*?)</a>')){ $href=$a.Groups[1].Value; if($href -ne 'index.html' -and $pathOf[$href]){ $trail+=,@((Get-Text $a.Groups[2].Value),($site+$pathOf[$href])) } }
    }
    $trail+=,@($v[4],$url)
    $i=0; $items=foreach($x in $trail){ $i++; [ordered]@{'@type'='ListItem';position=$i;name=$x[0];item=$x[1]} }
    $graph=[ordered]@{'@context'='https://schema.org';'@graph'=@(
      [ordered]@{'@type'='WebPage';'@id'="$url#webpage";url=$url;name=(Get-Text $v[0]);description=(Get-Text $v[1]);inLanguage='en-IN';isPartOf=@{'@id'="$site/#website"};about=@{'@id'="$site/#school"};primaryImageOfPage="$site/images/$($v[3])"},
      [ordered]@{'@type'='WebSite';'@id'="$site/#website";url="$site/";name='New Era Public School, Dwarka';publisher=@{'@id'="$site/#school"}},
      [ordered]@{'@type'='School';'@id'="$site/#school";name='New Era Public School, Dwarka';url="$site/";telephone='+91-9910119040';email='info@nepsdwarka.com';address=[ordered]@{'@type'='PostalAddress';streetAddress='Sector 25, Dwarka';addressLocality='New Delhi';postalCode='110077';addressCountry='IN'}},
      [ordered]@{'@type'='BreadcrumbList';itemListElement=@($items)}
    )}
    $top=$head.Replace('{{title}}',$v[0]).Replace('{{desc}}',$v[1]).Replace('{{path}}',$v[2]).Replace('{{img}}',$v[3]).Replace('<!--ROBOTS-->',$(if($v.Count -gt 5){"<meta name=`"robots`" content=`"$($v[5])`">"}else{''}))
    $top=$top.Replace('<!--SCHEMA-->','<script type="application/ld+json">'+(ConvertTo-JsonText $graph)+'</script>')
    $c=$top+"<body>`n<!--HEADER-->`n"+$c.Substring($m.Length)+"`n<!--FOOTER-->`n</body>`n</html>`n"
  }
  $c=$c.Replace('<!--ANAV-->',$nav.Replace("href=`"$p`"","href=`"$p`" aria-current=`"page`"")).Replace('<!--CALC-->',$calc).Replace('<!--ENQUIRY-->',$enq)
  if($c.Contains('<!--FAQSCHEMA-->')){
    $qs=[regex]::Matches($c,'<details class="q"(?: open)?><summary>(.*?)</summary><div>(.*?)</div></details>',[Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object {
      @{'@type'='Question';name=(Get-Text $_.Groups[1].Value);acceptedAnswer=@{'@type'='Answer';text=(Get-Text $_.Groups[2].Value)}}
    }
    $tag=''
    if($qs){ $tag='<script type="application/ld+json">'+(ConvertTo-JsonText @{'@context'='https://schema.org';'@type'='FAQPage';mainEntity=@($qs)})+'</script>' }
    $c=$c.Replace("<!--FAQSCHEMA-->`n",$(if($tag){"$tag`n"}else{''})).Replace("<!--FAQSCHEMA-->`r`n",$(if($tag){"$tag`r`n"}else{''}))
  }
  $c=$c.Replace('<!--HEADER-->',$h).Replace('<!--FOOTER-->',$f)
  [IO.File]::WriteAllText("$o\$p",$c,$enc); "built $p $([math]::Round($c.Length/1KB))KB"
}
# Sitemap, with each page's last-edited date
$sm='<?xml version="1.0" encoding="UTF-8"?>'+"`n"+'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+"`n"+(($sitemap | Sort-Object { $_[0] } | ForEach-Object { "  <url><loc>$site$($_[0])</loc><lastmod>$($_[1].LastWriteTime.ToString('yyyy-MM-dd'))</lastmod></url>" }) -join "`n")+"`n</urlset>`n"
[IO.File]::WriteAllText("$o\sitemap.xml",$sm,$enc); "sitemap: $($sitemap.Count) pages"
