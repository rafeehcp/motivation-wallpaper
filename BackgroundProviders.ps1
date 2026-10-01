# Loaded by SetMotivationWallpaper.ps1; shares its service and JSON helpers.
function ConvertTo-CommonsCandidate($Page,$MinWidth,$MinHeight) {
 try {
  $info=$Page.imageinfo[0];$meta=$info.extmetadata
  $license=[string]$meta.LicenseShortName.value;$licenseUrl=[string]$meta.LicenseUrl.value
  # Deliberately narrow: only reviewed CC0 photographs, no inferred public-domain status.
  if($license -notmatch '^CC0(?: 1\.0)?$' -or $licenseUrl -notmatch '^https?://creativecommons\.org/publicdomain/zero/1\.0/(?:deed\.[a-z-]+)?$'){return $null}
  if($meta.PSObject.Properties['Restrictions'] -and $meta.Restrictions.value){return $null}
  if($info.mime -notin @('image/jpeg','image/png') -or $info.width -lt $MinWidth -or $info.height -lt $MinHeight){return $null}
  $download=[string]$info.url
  if($info.PSObject.Properties['thumburl'] -and $info.thumbwidth -ge $MinWidth -and $info.thumbheight -ge $MinHeight){$download=[string]$info.thumburl}
  elseif($info.size -gt 10485760){return $null}
  if(([uri]$download).Scheme -ne 'https' -or ([uri]$download).Host -notin @('upload.wikimedia.org','thumb.wikimedia.org')){return $null}
  if(([uri]$info.descriptionurl).Scheme -ne 'https' -or ([uri]$info.descriptionurl).Host -ne 'commons.wikimedia.org'){return $null}
  $artist=[Net.WebUtility]::HtmlDecode(([string]$meta.Artist.value -replace '<[^>]*>','')) -replace '\s+',' '
  if(!$artist){$artist='Commons contributor'}
  if($artist.Length -gt 70){$artist=$artist.Substring(0,67)+'...'}
  return @{id=('commons:'+$Page.pageid+':'+$info.sha1);url=[string]$info.descriptionurl;download=$download;photographer=$artist.Trim();source='Commons';license='CC0 1.0';licenseUrl='https://creativecommons.org/publicdomain/zero/1.0/';mime=$info.mime}
 }catch{return $null}
}
function Get-CommonsBackground($Folder,$Recent,$MinWidth,$MinHeight) {
 $catalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'commons-backgrounds.json') -Raw|ConvertFrom-Json
 $headers=@{'User-Agent'='MotivationWallpaper/0.1 (https://github.com/rafeehcp/motivation-wallpaper)'}
 $cachePath=Join-Path $Folder 'commons-metadata.json'
 $pages=@()
 if((Test-Path -LiteralPath $cachePath) -and (Get-Item -LiteralPath $cachePath).LastWriteTime -gt (Get-Date).AddDays(-1)){$loaded=Get-Content -LiteralPath $cachePath -Raw|ConvertFrom-Json;$pages=@($loaded)}
 else {
  $titles=($catalog|ForEach-Object{$_.title}) -join '|'
  $uri='https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&prop=imageinfo&iiprop=url%7Csize%7Csha1%7Cmime%7Cextmetadata&iiurlwidth=3840&titles='+[uri]::EscapeDataString($titles)
  $response=Invoke-Service -Uri $uri -Headers $headers -TimeoutSeconds 10 -Attempts 1
  $pages=@($response.query.pages);Save-Json $cachePath $pages
 }
 $allowed=@($catalog|ForEach-Object{$_.title})
 $candidates=@(foreach($page in $pages){if($page.title -in $allowed){$candidate=ConvertTo-CommonsCandidate $page $MinWidth $MinHeight;if($candidate -and $candidate.id -notin $Recent){$candidate}}})
 if(!$candidates.Count){throw 'No eligible unused Commons photo in the reviewed collection.'}
 $selected=$candidates|Get-Random
 $extension=if($selected.mime -eq 'image/png'){'.png'}else{'.jpg'}
 $path=Join-Path $Folder ('commons_'+(Get-QuoteId $selected.id)+'_'+$MinWidth+'x'+$MinHeight+$extension)
 # Validate before rendering. Partial downloads are never retained as valid cache entries.
 try {
  if(!(Test-Path -LiteralPath $path)){Invoke-Service -Uri $selected.download -Headers $headers -OutFile $path -TimeoutSeconds 10 -Attempts 1}
  $image=[Drawing.Image]::FromFile($path)
  try{if($image.Width -lt $MinWidth -or $image.Height -lt $MinHeight){throw 'Downloaded photo is too small.'}}finally{$image.Dispose()}
 }catch{if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path};throw}
 $selected.path=$path;return $selected
}
function Get-GeneratedBackground($Folder,$Theme,$Width,$Height) {
 $id='generated:'+([guid]::NewGuid().ToString('N'));$seed=Get-Random -Minimum 0 -Maximum ([int]::MaxValue)
 $path=Join-Path $Folder (($id -replace ':','_')+'.png')
 [Motivation.Renderer]::GenerateBackground($path,[int]$Width,[int]$Height,[string]$Theme,[int]$seed)
 return @{id=$id;path=$path;photographer='';url='';source='Generated';license='Original procedural artwork';licenseUrl='';seed=$seed}
}
function Get-Background($Folder,$Recent,$MinWidth,$MinHeight,$Theme='Grounded and practical') {
 if($BackgroundSource -eq 'Commons'){
  try{return Get-CommonsBackground $Folder $Recent $MinWidth $MinHeight}
  catch{if(!$Automatic){Write-Host 'Commons photo unavailable; creating a fresh generated background.'}}
 }
 return Get-GeneratedBackground $Folder $Theme $MinWidth $MinHeight
}
function Get-BackgroundCredit($Background) {
 switch($Background['source']) {
  'Generated' {return 'Original generated background'}
  'Commons' {return "Photo: $($Background.photographer) / Wikimedia Commons / CC0"}
  default {return 'Background preview'}
 }
}
function Get-BackgroundHtml($Background) {
 $text=[Net.WebUtility]::HtmlEncode((Get-BackgroundCredit $Background))
 $html='<p>'+$text+'</p>'
 if($Background.url){$html+='<p><a href="'+[Net.WebUtility]::HtmlEncode($Background.url)+'">Photo source</a></p>'}
 if($Background['licenseUrl']){$html+='<p><a href="'+[Net.WebUtility]::HtmlEncode($Background.licenseUrl)+'">'+[Net.WebUtility]::HtmlEncode($Background.license)+'</a></p>'}
 return $html
}
