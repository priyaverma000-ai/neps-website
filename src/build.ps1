# Builds the site: fills each src\tpl page with the shared partials (_head, _header, _footer...)
# and writes the finished page to the site root. Run: powershell -File src\build.ps1
$s= if($args[0]){$args[0]}else{$PSScriptRoot}; $o= if($args[1]){$args[1]}else{Split-Path $PSScriptRoot -Parent}; $t="$s\tpl"
$enc=New-Object Text.UTF8Encoding $false
function Part($n){ [IO.File]::ReadAllText("$t\_$n.html",$enc) }
$urls=New-Object Collections.Generic.List[string]; $urls.Add('/'); $urls.Add('/blog/'); $urls.Add('/blog/why-sports-matter-in-school')
$h=Part 'header'; $f=Part 'footer'; $head=Part 'head'; $enq=Part 'enquiry'; $calc=Part 'calc'; $nav=Part 'anav'
foreach($file in Get-ChildItem "$t\*.html" | Where-Object { $_.Name -notlike '_*' }){
  $p=$file.Name; $c=[IO.File]::ReadAllText($file.FullName,$enc)
  $m=[regex]::Match($c,'^<!--META (.*?)-->\r?\n',[Text.RegularExpressions.RegexOptions]::Singleline)
  if($m.Success){
    # title || description || canonical path || og image || breadcrumb name
    $v=$m.Groups[1].Value -split '\|\|' | ForEach-Object { $_.Trim() }
    $top=$head.Replace('{{title}}',$v[0]).Replace('{{desc}}',$v[1]).Replace('{{path}}',$v[2]).Replace('{{img}}',$v[3]).Replace('{{name}}',$v[4]).Replace('<!--ROBOTS-->',$(if($v.Count -gt 5){"<meta name=`"robots`" content=`"$($v[5])`">"}else{''}))
    if($v.Count -le 5){ $urls.Add($v[2]) }
    $c=$top+"<body>`n<!--HEADER-->`n"+$c.Substring($m.Length)+"`n<!--FOOTER-->`n</body>`n</html>`n"
  }
  $c=$c.Replace('<!--ANAV-->',$nav.Replace("href=`"$p`"","href=`"$p`" aria-current=`"page`"")).Replace('<!--CALC-->',$calc).Replace('<!--ENQUIRY-->',$enq)
  if($c.Contains('<!--FAQSCHEMA-->')){
    $qs=[regex]::Matches($c,'<details class="q"(?: open)?><summary>(.*?)</summary><div>(.*?)</div></details>',[Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object {
      $q=[Net.WebUtility]::HtmlDecode(($_.Groups[1].Value -replace '<[^>]+>',''))
      $a=[Net.WebUtility]::HtmlDecode(($_.Groups[2].Value -replace '<[^>]+>',''))
      @{'@type'='Question';name=$q;acceptedAnswer=@{'@type'='Answer';text=$a}}
    }
    $tag=''
    if($qs){ $tag='<script type="application/ld+json">'+(@{'@context'='https://schema.org';'@type'='FAQPage';mainEntity=@($qs)} | ConvertTo-Json -Depth 6 -Compress)+'</script>' }
    $c=$c.Replace("<!--FAQSCHEMA-->`n",$(if($tag){"$tag`n"}else{''})).Replace("<!--FAQSCHEMA-->`r`n",$(if($tag){"$tag`r`n"}else{''}))
  }
  $c=$c.Replace('<!--HEADER-->',$h).Replace('<!--FOOTER-->',$f)
  [IO.File]::WriteAllText("$o\$p",$c,$enc); "built $p $([math]::Round($c.Length/1KB))KB"
}
$sm='<?xml version="1.0" encoding="UTF-8"?>'+"`n"+'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+"`n"+(($urls | ForEach-Object { "  <url><loc>https://nepsdwarka.com$_</loc></url>" }) -join "`n")+"`n</urlset>`n"
[IO.File]::WriteAllText("$o\sitemap.xml",$sm,$enc); "sitemap: $($urls.Count) pages"
