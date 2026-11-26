# Builds the site: fills each src/tpl page with the shared partials (_head, _header, _footer...),
# turns the Markdown posts in content/blog and content/news into pages, and writes the finished
# pages to the site root. Works in Windows PowerShell 5.1 and PowerShell 7 (Windows, Linux, macOS).
# Run: powershell -File src/build.ps1   (or: pwsh src/build.ps1)
$s= if($args[0]){$args[0]}else{$PSScriptRoot}; $o= if($args[1]){$args[1]}else{Split-Path $PSScriptRoot -Parent}; $t="$s/tpl"
$enc=New-Object Text.UTF8Encoding $false
$site='https://nepsdwarka.com'
$inv=[Globalization.CultureInfo]::InvariantCulture
function Part($n){ [IO.File]::ReadAllText("$t/_$n.html",$enc) }
function Get-Text($html){ ([Net.WebUtility]::HtmlDecode(($html -replace '<[^>]+>','')) -replace '\s+',' ').Trim() }
# Windows PowerShell writes ' & < > as backslash-u escapes (u0027, u0026, u003c, u003e); PowerShell 7 does not. Use the plain characters so both give the same output.
function ConvertTo-JsonText($x){ $j=($x | ConvertTo-Json -Depth 8 -Compress); $u=[string][char]92+'u00'; $j.Replace($u+'27',[string][char]39).Replace($u+'26','&').Replace($u+'3c','<').Replace($u+'3e','>') }
function Enc($x){ [Net.WebUtility]::HtmlEncode([string]$x) }
$h=Part 'header'; $f=Part 'footer'; $head=Part 'head'; $enq=Part 'enquiry'; $calc=Part 'calc'; $nav=Part 'anav'; $tst=Part 'testimonials'
# Page FAQs live in src/faqs.json: { "page.html": { "topic": "...", "faq": [[question, answer], ...] } }
$faqs=[IO.File]::ReadAllText("$s/faqs.json",$enc) | ConvertFrom-Json
function Get-FaqSection($entry){
  $items=foreach($qa in $entry.faq){ '    <details class="q"><summary>'+[Net.WebUtility]::HtmlEncode($qa[0])+'</summary><div>'+[Net.WebUtility]::HtmlEncode($qa[1])+'</div></details>' }
  "<section class=`"sec page-faq`"><div class=`"wrap slim`">`n  <div class=`"sec-head rv`"><span class=`"eyebrow`">FAQ</span><h2 class=`"title`">Questions about $([Net.WebUtility]::HtmlEncode($entry.topic))</h2></div>`n  <div class=`"qa rv`">`n"+($items -join "`n")+"`n  </div>`n</div></section>`n"
}

# ---------------------------------------------------------------------------------------------
# Blog and news posts: Markdown files with a front matter block, written in the /admin editor
# (Decap CMS) or by hand. content/blog/<slug>.md -> blog-<slug>.html, content/news/<slug>.md -> news-<slug>.html
# ---------------------------------------------------------------------------------------------
function Read-FrontMatter([string]$raw){
  $raw=$raw.Replace("`r`n","`n"); $meta=@{}; $body=$raw
  $m=[regex]::Match($raw,'^---\n(.*?)\n---\n?(.*)$',[Text.RegularExpressions.RegexOptions]::Singleline)
  if($m.Success){
    $body=$m.Groups[2].Value; $lines=$m.Groups[1].Value -split "`n"; $key=$null; $block=$null; $buf=@()
    foreach($ln in $lines){
      if($block -and ($ln -match '^\s+\S' -or $ln -eq '')){ $buf+=$ln.Trim(); continue }
      if($block){ $meta[$key]= if($block -like '|*'){ $buf -join "`n" } else { ($buf -join ' ').Trim() }; $block=$null; $buf=@() }
      if($ln -match '^\s+-\s*(.*)$' -and $key){ if($meta[$key] -isnot [Collections.ArrayList]){ $meta[$key]=New-Object Collections.ArrayList }; [void]$meta[$key].Add((Get-Plain $Matches[1])); continue }
      if($ln -match '^([A-Za-z_][\w-]*):\s*(.*)$'){
        $key=$Matches[1]; $v=$Matches[2].Trim()
        if($v -match '^[>|][-+]?$'){ $block=$v; $buf=@() } elseif($v -eq ''){ $meta[$key]=$null } else { $meta[$key]=Get-Plain $v }
      }
    }
    if($block){ $meta[$key]= if($block -like '|*'){ $buf -join "`n" } else { ($buf -join ' ').Trim() } }
  }
  @{meta=$meta;body=$body}
}
function Get-Plain([string]$v){
  $v=$v.Trim()
  if($v.Length -ge 2 -and $v.StartsWith('"') -and $v.EndsWith('"')){ return $v.Substring(1,$v.Length-2).Replace('\"','"').Replace('\\','\') }
  if($v.Length -ge 2 -and $v.StartsWith("'") -and $v.EndsWith("'")){ return $v.Substring(1,$v.Length-2).Replace("''","'") }
  $v
}
function Get-Slug([string]$x){ (($x.ToLower() -replace '[^a-z0-9]+','-').Trim('-')) }
function Get-Src([string]$x){ if(-not $x){ return '' }; $x=$x.Trim(); if($x -match '^https?://'){ $x } else { $x.TrimStart('/') } }
function ConvertTo-Inline([string]$x){
  $x=Enc $x
  $x=[regex]::Replace($x,'!\[([^\]]*)\]\(([^)\s]+)\)',{ param($m) "<img loading=`"lazy`" src=`"$(Get-Src $m.Groups[2].Value)`" alt=`"$($m.Groups[1].Value)`">" })
  $x=[regex]::Replace($x,'\[([^\]]+)\]\(([^)\s]+)\)',{ param($m) $u=$m.Groups[2].Value; if($u.StartsWith('/') -and -not $u.StartsWith('//')){ $u=$u.TrimStart('/') }; "<a href=`"$u`">$($m.Groups[1].Value)</a>" })
  $x=[regex]::Replace($x,'\*\*(.+?)\*\*','<strong>$1</strong>')
  $x=[regex]::Replace($x,'(?<![\*\w])\*(?=\S)(.+?)(?<=\S)\*(?!\*)','<em>$1</em>')
  $x=[regex]::Replace($x,'`([^`]+)`','<code>$1</code>')
  $x
}
function ConvertFrom-Md([string]$md){
  $out=New-Object Collections.Generic.List[string]; $mode=''; $buf=New-Object Collections.Generic.List[string]
  $flush={
    if($buf.Count){
      switch($mode){
        'p'     { $out.Add('<p>'+(ConvertTo-Inline (($buf -join ' ').Trim()))+'</p>') }
        'ul'    { $out.Add('<ul class="tick">'+(($buf | ForEach-Object { '<li>'+(ConvertTo-Inline $_)+'</li>' }) -join '')+'</ul>') }
        'ol'    { $out.Add('<ol class="tick" style="list-style:decimal;padding-left:22px">'+(($buf | ForEach-Object { '<li>'+(ConvertTo-Inline $_)+'</li>' }) -join '')+'</ol>') }
        'quote' { $out.Add('<p class="pull">'+(ConvertTo-Inline (($buf -join ' ').Trim()))+'</p>') }
        'raw'   { $out.Add($buf -join "`n") }
      }
    }
    $buf.Clear(); Set-Variable -Name mode -Value '' -Scope 1
  }
  foreach($ln in ($md.Replace("`r`n","`n") -split "`n")){
    if($mode -eq 'raw' -and $ln.Trim() -ne ''){ $buf.Add($ln); continue }
    if($ln.Trim() -eq ''){ & $flush; continue }
    if($ln -match '^(#{2,4})\s+(.+?)\s*#*$'){ & $flush; $n=$Matches[1].Length; $txt=$Matches[2]; $id=Get-Slug (Get-Text (ConvertTo-Inline $txt)); $out.Add("<h$n id=`"$id`">$(ConvertTo-Inline $txt)</h$n>"); continue }
    if($ln -match '^#\s+(.+)$'){ & $flush; $out.Add("<h2>$(ConvertTo-Inline $Matches[1])</h2>"); continue }
    if($ln -match '^\s*!\[([^\]]*)\]\(([^)\s]+)\)\s*$'){ & $flush; $alt=Enc $Matches[1]; $out.Add("<figure><img loading=`"lazy`" src=`"$(Get-Src $Matches[2])`" alt=`"$alt`">$(if($alt){"<figcaption>$alt</figcaption>"})</figure>"); continue }
    if($ln -match '^\s{0,3}[-*+]\s+(.*)$'){ if($mode -ne 'ul'){ & $flush; $mode='ul' }; $buf.Add($Matches[1]); continue }
    if($ln -match '^\s{0,3}\d+[.)]\s+(.*)$'){ if($mode -ne 'ol'){ & $flush; $mode='ol' }; $buf.Add($Matches[1]); continue }
    if($ln -match '^>\s?(.*)$'){ if($mode -ne 'quote'){ & $flush; $mode='quote' }; $buf.Add($Matches[1]); continue }
    if($ln -match '^\s*<' -and $mode -eq ''){ $mode='raw'; $buf.Add($ln); continue }
    if(($mode -eq 'ul' -or $mode -eq 'ol') -and $ln -match '^\s{2,}\S'){ $buf[$buf.Count-1]+=' '+$ln.Trim(); continue }
    if($mode -ne 'p'){ & $flush; $mode='p' }; $buf.Add($ln.Trim())
  }
  & $flush
  $out -join "`n"
}
$posts=New-Object Collections.Generic.List[object]
foreach($kind in 'blog','news'){
  $dir="$o/content/$kind"; if(-not (Test-Path $dir)){ continue }
  foreach($md in (Get-ChildItem "$dir/*.md")){
    $fm=Read-FrontMatter ([IO.File]::ReadAllText($md.FullName,$enc)); $mt=$fm.meta
    if(-not $mt.title -or ("$($mt.draft)" -eq 'true')){ continue }
    $slug=Get-Slug $md.BaseName
    $date= try { [datetime]::Parse([string]$mt.date,$inv) } catch { $md.LastWriteTime }
    $words=([regex]::Matches($fm.body,'\w+')).Count
    $posts.Add([pscustomobject]@{Kind=$kind;Slug=$slug;File="$kind-$slug.html";Path="/$kind-$slug";Title=[string]$mt.title;Date=$date;Category=$(if($mt.category){[string]$mt.category}else{ if($kind -eq 'blog'){'Parent Journal'}else{'News'} });Summary=[string]$mt.summary;Image=(Get-Src $mt.image);Alt=[string]$mt.image_alt;Featured=("$($mt.featured)" -eq 'true');Takeaways=@($mt.takeaways | Where-Object { $_ });Body=$fm.body;Minutes=[Math]::Max(1,[Math]::Ceiling($words/200))})
  }
}
$posts=@($posts | Sort-Object @{Expression='Date';Descending=$true},@{Expression='Kind';Descending=$false},@{Expression='Slug';Descending=$false})
function Get-Card($p){
  $img= if($p.Image){ $p.Image } else { 'images/campus-wide-sm.jpg' }
  $alt= if($p.Alt){ Enc $p.Alt } else { '' }
  "<a class=`"post rv`" data-cat=`"$(Get-Slug $p.Category)`" href=`"$($p.File)`"><img loading=`"lazy`" src=`"$img`" alt=`"$alt`" width=`"800`" height=`"500`"><div class=`"post-b`"><div class=`"meta`"><span class=`"cat`">$(Enc $p.Category)</span>$($p.Date.ToString('d MMM yyyy',$inv))</div><h3>$(Enc $p.Title)</h3>$(if($p.Summary){"<p>$(Enc $p.Summary)</p>"})</div></a>"
}
function Get-PostPage($p){
  $isBlog=$p.Kind -eq 'blog'
  $section= if($isBlog){ @('blog.html','Parent Journal') } else { @('news.html','News') }
  $ogImg= if($p.Image -and $p.Image -like 'images/*'){ $p.Image.Substring(7) } else { 'campus-wide.jpg' }
  $bodyHtml=ConvertFrom-Md $p.Body
  $toc=[regex]::Matches($bodyHtml,'<h2 id="([^"]+)">(.*?)</h2>') | ForEach-Object { "        <a href=`"#$($_.Groups[1].Value)`">$($_.Groups[2].Value)</a>" }
  $long=$p.Date.ToString('d MMMM yyyy',$inv)
  $cover= if($p.Image){ "  <div class=`"acover`"><img src=`"$($p.Image)`" alt=`"$(Enc $p.Alt)`" fetchpriority=`"high`"></div>`n" } else { '' }
  $take= if($p.Takeaways.Count){ "      <div class=`"takeaway`">`n        <h2>In short</h2>`n        <ul class=`"tick`">"+(($p.Takeaways | ForEach-Object { "<li>$(ConvertTo-Inline $_)</li>" }) -join '')+"</ul>`n      </div>`n" } else { '' }
  $ld=[ordered]@{'@context'='https://schema.org';'@type'=$(if($isBlog){'BlogPosting'}else{'NewsArticle'});headline=$p.Title;datePublished=$p.Date.ToString('yyyy-MM-dd');dateModified=$p.Date.ToString('yyyy-MM-dd');inLanguage='en-IN';image="$site/images/$ogImg";author=[ordered]@{'@type'='Organization';name='New Era Public School, Dwarka';url="$site/"};publisher=[ordered]@{'@type'='Organization';name='New Era Public School, Dwarka';logo=[ordered]@{'@type'='ImageObject';url="$site/images/logo-full.png"}};mainEntityOfPage="$site$($p.Path)"}
  $share=[uri]::EscapeDataString("$($p.Title): $site$($p.Path)")
  $desc= if($p.Summary){ $p.Summary } else { $p.Title }
  $tocBlock= if($toc){ "      <div class=`"card toc`">`n        <h3>In this article</h3>`n"+($toc -join "`n")+"`n      </div>`n" } else { '' }
@"
<!--META $(Enc $p.Title) | NEPS Dwarka||$(Enc $desc)||$($p.Path)||$ogImg||$(Enc $p.Title)-->
<div class="progress" aria-hidden="true"></div>
<main id="main">
<script type="application/ld+json">$(ConvertTo-JsonText $ld)</script>
<header class="ahead"><div class="wrap">
  <p class="crumbs"><a href="index.html">Home</a> / <a href="$($section[0])">$($section[1])</a></p>
  <h1>$(Enc $p.Title)</h1>
  <div class="meta"><span class="cat">$(Enc $p.Category)</span>$long &middot; $($p.Minutes) min read</div>
</div></header>
<div class="wrap">
$cover  <div class="alayout">
    <article class="prose">
$take$bodyHtml
      <div class="inline-cta">
        <h3>See New Era for yourself</h3>
        <p>Walk the campus with our team, and bring your questions.</p>
        <div class="row"><button class="btn btn-gold" data-open="visit">Book a Campus Visit</button><a class="btn btn-light" href="admissions.html">Admissions 2027-28</a></div>
      </div>
      <div class="author"><img src="images/logo-mark.png" alt="" width="56" height="49"><div><b>New Era Editorial Team</b>New Era Public School, Dwarka</div></div>
    </article>
    <aside class="side aside-sticky">
$tocBlock      <a class="btn btn-gold btn-block" href="https://wa.me/?text=$share" data-loc="share">Share on WhatsApp</a>
      <a class="btn btn-ghost btn-block" style="margin-top:10px" href="$($section[0])">More from $($section[1]) &rarr;</a>
    </aside>
  </div>
</div>
</main>
"@
}

# Every page to build: the templates in src/tpl plus one page per post
$pages=New-Object Collections.Generic.List[object]
# Last-edited date for the sitemap: the last git commit that touched the page source (stable on any machine), else the file time
function Get-Mod($file){ $d=$null; try { $d=(git -C "$s" log -1 --format=%cs -- "tpl/$($file.Name)" 2>$null) } catch {}; if($d){ [datetime]::ParseExact([string]$d,'yyyy-MM-dd',$inv) } else { $file.LastWriteTime } }
foreach($file in (Get-ChildItem "$t/*.html" | Where-Object { $_.Name -notlike '_*' })){ $pages.Add([pscustomobject]@{Name=$file.Name;Content=[IO.File]::ReadAllText($file.FullName,$enc);Mod=(Get-Mod $file)}) }
foreach($p in $posts){ $pages.Add([pscustomobject]@{Name=$p.File;Content=(Get-PostPage $p);Mod=$p.Date}) }
# Lists of posts on the blog, news and home pages
$blogPosts=@($posts | Where-Object { $_.Kind -eq 'blog' }); $newsPosts=@($posts | Where-Object { $_.Kind -eq 'news' })
$feat=@($blogPosts | Where-Object { $_.Featured })[0]; if(-not $feat){ $feat=$blogPosts[0] }

# Instagram reels on the home page (content/home-instagram.json, edited in /admin)
$reelHtml=''; $igTitle='See school life on Instagram'
if(Test-Path "$o/content/home-instagram.json"){
  $ig=[IO.File]::ReadAllText("$o/content/home-instagram.json",$enc) | ConvertFrom-Json
  if($ig.title){ $igTitle=[string]$ig.title }
  $n=0; $reelHtml=(@($ig.reels) | ForEach-Object {
    $m=[regex]::Match([string]$_,'instagram\.com/(?:[\w.]+/)?(reel|p)/([\w-]+)')
    if($m.Success){ $n++; "    <div class=`"ig-item`"><iframe data-src=`"https://www.instagram.com/$($m.Groups[1].Value)/$($m.Groups[2].Value)/embed/`" title=`"New Era Public School on Instagram, video $n`" scrolling=`"no`" allowtransparency=`"true`"></iframe></div>" }
  }) -join "`n"
}
# Media coverage on the home page and In the news (content/media-coverage.json, edited in /admin)
$people=@{'Rohit Chopra'=@('lead-rohit-sm.jpg','Director');'Dr. Priti Ramendra'=@('lead-priti-sm.jpg','Head of School');'Mrs. Usha Chopra'=@('lead-usha-sm.jpg','Chairperson')}
$media=$null; if(Test-Path "$o/content/media-coverage.json"){ $media=[IO.File]::ReadAllText("$o/content/media-coverage.json",$enc) | ConvertFrom-Json }
function Get-MediaCard($it,[switch]$OnHome){
  $d= try { ([datetime]::Parse([string]$it.date,$inv)).ToString('d MMM yyyy',$inv) } catch { [string]$it.date }
  $head= if($it.url){ "<a href=`"$(Enc $it.url)`" rel=`"noopener`">$(Enc $it.headline)</a>" } else { Enc $it.headline }
  $who=''; if($it.person -and $people[[string]$it.person]){ $pp=$people[[string]$it.person]; $who="<div class=`"m-who`"><img loading=`"lazy`" src=`"images/$($pp[0])`" alt=`"`" width=`"40`" height=`"40`"><span><b>$(Enc $it.person)</b>$($pp[1])</span></div>" }
  if($OnHome){ "    <li class=`"m-card rv`"><span class=`"m-out`">$(Enc $it.outlet)</span><span class=`"m-meta`">$(Enc $it.kind) &middot; $d</span><h3>$head</h3><p>$(Enc $it.summary)</p>$who</li>" }
  else { "    <li class=`"rv`"><span class=`"stat`">$(Enc $it.outlet) &middot; $d</span><h3>$head</h3><p>$(Enc $it.summary)</p>$who</li>" }
}
$mediaHome=''; $pressList=''
if($media){
  $all=@($media.items | Sort-Object { [string]$_.date } -Descending)
  $strip=(@($media.featured_in) | ForEach-Object { "<li>$(Enc $_)</li>" }) -join ''
  $cards=(@($all | Where-Object { "$($_.home)" -eq 'True' -or "$($_.home)" -eq 'true' } | Select-Object -First 4) | ForEach-Object { Get-MediaCard $_ -OnHome }) -join "`n"
  $mediaHome="<section class=`"sec media-band`" id=`"media`"><div class=`"wrap`">`n  <div class=`"sec-head rv`"><span class=`"eyebrow`">In the media</span><h2 class=`"title`">New Era in the national press</h2><p class=`"lead`">Our leaders write and speak on skills, wellbeing and the future of school education.</p></div>`n  <ul class=`"m-strip rv`" aria-label=`"Featured in`">$strip</ul>`n  <ul class=`"m-grid`">`n$cards`n  </ul>`n  <p class=`"rv`" style=`"margin-top:20px`"><a class=`"link link-light`" href=`"in-the-news.html`">All media coverage &rarr;</a></p>`n</div></section>"
  $pressList="  <ul class=`"press`">`n"+(($all | ForEach-Object { Get-MediaCard $_ }) -join "`n")+"`n  </ul>"
}
foreach($pg in $pages){
  if($pg.Name -eq 'blog.html'){
    $featHtml= if($feat){ "<a class=`"feat`" href=`"$($feat.File)`">`n      <img src=`"$(if($feat.Image){$feat.Image}else{'images/campus-wide.jpg'})`" alt=`"$(Enc $feat.Alt)`" fetchpriority=`"high`">`n      <div class=`"feat-b`">`n        <div class=`"meta`"><span class=`"cat`">$(Enc $feat.Category)</span>$($feat.Date.ToString('MMM yyyy',$inv)) &middot; $($feat.Minutes) min read</div>`n        <h2>$(Enc $feat.Title)</h2>`n        <p>$(Enc $feat.Summary)</p>`n      </div>`n    </a>" } else { '' }
    $cats=@($blogPosts | ForEach-Object { $_.Category } | Select-Object -Unique)
    $chips=(@('<button class="chip" data-filter="all" aria-pressed="true">All</button>')+($cats | ForEach-Object { "<button class=`"chip`" data-filter=`"$(Get-Slug $_)`" aria-pressed=`"false`">$(Enc $_)</button>" })) -join "`n  "
    $pg.Content=$pg.Content.Replace('<!--BLOGFEAT-->',$featHtml).Replace('<!--BLOGCHIPS-->',$chips).Replace('<!--BLOGCARDS-->',(($blogPosts | ForEach-Object { '      '+(Get-Card $_) }) -join "`n"))
  }
  if($pg.Name -eq 'news.html'){ $pg.Content=$pg.Content.Replace('<!--NEWSCARDS-->',(($newsPosts | ForEach-Object { '    '+(Get-Card $_) }) -join "`n")) }
  if($pg.Name -eq 'index.html'){
    $pg.Content=$pg.Content.Replace('<!--HOMELATEST-->',((@($posts | Select-Object -First 3) | ForEach-Object { '    '+(Get-Card $_) }) -join "`n")).Replace('<!--MEDIACOVERAGE-->',$mediaHome)
    $igSec= if($reelHtml){ "<section class=`"sec ig-sec`" id=`"instagram`"><div class=`"wrap`">`n  <div class=`"sec-head rv`"><span class=`"eyebrow`">@newerapublicschool.dwarka</span><h2 class=`"title`">$(Enc $igTitle)</h2></div>`n  <div class=`"ig-rail`" tabindex=`"0`" aria-label=`"Instagram videos, scroll sideways`">`n$reelHtml`n  </div>`n  <p class=`"rv`" style=`"margin-top:16px`"><a class=`"btn btn-ghost`" href=`"https://www.instagram.com/newerapublicschool.dwarka/`" rel=`"noopener`">Follow us on Instagram</a></p>`n</div></section>" } else { '' }
    $pg.Content=$pg.Content.Replace('<!--INSTAREELS-->',$igSec)
  }
  if($pg.Name -eq 'in-the-news.html' -and $pressList){ $pg.Content=$pg.Content.Replace('<!--PRESSLIST-->',$pressList) }
}
# Remove pages of posts that were deleted or unpublished
Get-ChildItem "$o/*.html" | Where-Object { $_.Name -match '^(blog|news)-.+\.html$' -and -not ($posts.File -contains $_.Name) } | Remove-Item

# First pass: each page's public address, so breadcrumbs and the sitemap can use it
$pathOf=@{'index.html'='/';'blog.html'='/blog'}
$sitemap=New-Object Collections.Generic.List[object]
foreach($pg in $pages){
  $m=[regex]::Match($pg.Content,'^<!--META (.*?)-->')
  if($m.Success){ $v=$m.Groups[1].Value -split '\|\|' | ForEach-Object { $_.Trim() }; $pathOf[$pg.Name]=$v[2]; if($v.Count -le 5){ $sitemap.Add(@($v[2],$pg)) } }
  elseif($pathOf[$pg.Name]){ $sitemap.Add(@($pathOf[$pg.Name],$pg)) }
}

foreach($pg in $pages){
  $p=$pg.Name; $c=$pg.Content
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
    $trail+=,@((Get-Text $v[4]),$url)
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
  $c=$c.Replace('<!--ANAV-->',$nav.Replace("href=`"$p`"","href=`"$p`" aria-current=`"page`"")).Replace('<!--CALC-->',$calc).Replace('<!--ENQUIRY-->',$enq).Replace('<!--TESTIMONIALS-->',$(if($p -eq 'reviews.html'){ [regex]::Replace($tst,'\s*<p class="rv"[^>]*><a class="link" href="reviews.html">.*?</p>','') }else{ $tst }))
  $entry=$faqs.$p
  if($entry -and $entry.faq.Count){
    $sec=Get-FaqSection $entry
    if($c.Contains('<!--ENQUIRY-->')){ $c=$c.Replace('<!--ENQUIRY-->',$sec+'<!--ENQUIRY-->') }
    elseif($c.Contains('<section class="sec final">')){ $c=$c.Replace('<section class="sec final">',$sec+'<section class="sec final">') }
    else { $c=$c.Replace('</main>',$sec+'</main>') }
    if(-not $c.Contains('<!--FAQSCHEMA-->')){ $c=$c.Replace('</head>',"<!--FAQSCHEMA-->`n</head>") }
  }
  if($c.Contains('<!--FAQSCHEMA-->')){
    $qs=[regex]::Matches($c,'<details class="q"(?: open)?><summary>(.*?)</summary><div>(.*?)</div></details>',[Text.RegularExpressions.RegexOptions]::Singleline) | ForEach-Object {
      [ordered]@{'@type'='Question';name=(Get-Text $_.Groups[1].Value);acceptedAnswer=[ordered]@{'@type'='Answer';text=(Get-Text $_.Groups[2].Value)}}
    }
    $tag=''
    if($qs){ $tag='<script type="application/ld+json">'+(ConvertTo-JsonText ([ordered]@{'@context'='https://schema.org';'@type'='FAQPage';mainEntity=@($qs)}))+'</script>' }
    $c=$c.Replace("<!--FAQSCHEMA-->`n",$(if($tag){"$tag`n"}else{''})).Replace("<!--FAQSCHEMA-->`r`n",$(if($tag){"$tag`r`n"}else{''}))
  }
  $c=$c.Replace('<!--HEADER-->',$h).Replace('<!--FOOTER-->',$f)
  # The 404 page can be shown at any depth (/a/b/c), so point its relative links at the site root
  if($p -eq '404.html'){ $c=$c.Replace("<head>`n","<head>`n<script>document.write('<base href=`"'+(/github\.io$/.test(location.hostname)?'/'+location.pathname.split('/')[1]+'/':'/')+'`">')</script>`n") }
  [IO.File]::WriteAllText("$o/$p",$c,$enc); "built $p $([math]::Round($c.Length/1KB))KB"
}
# Sitemap, with each page's last-edited date
$sm='<?xml version="1.0" encoding="UTF-8"?>'+"`n"+'<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+"`n"+(($sitemap | Sort-Object { ((([string]$_[0]).ToCharArray() | ForEach-Object { '{0:D5}' -f [int]$_ }) -join '') } | ForEach-Object { "  <url><loc>$site$($_[0])</loc><lastmod>$($_[1].Mod.ToString('yyyy-MM-dd'))</lastmod></url>" }) -join "`n")+"`n</urlset>`n"
[IO.File]::WriteAllText("$o/sitemap.xml",$sm,$enc); "sitemap: $($sitemap.Count) pages, $($posts.Count) posts"
