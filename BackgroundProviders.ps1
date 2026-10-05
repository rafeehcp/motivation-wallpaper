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
  if($info.PSObject.Properties['thumburl'] -and $info.thumbwidth -ge $MinWidth -and $info.thumbheight -ge $MinHeight){
   $download=[string]$info.thumburl
   # Commons serves only standard thumbnail widths, so a smaller iiurlwidth still returns 3840.
   # The 1920 file is about 40% of the bytes when it covers every monitor.
   if($MinWidth -le 1920 -and [Math]::Floor(1920*$info.height/$info.width) -ge $MinHeight){$download=$download -replace '/3840px-','/1920px-'}
  }
  elseif($info.size -gt 10485760){return $null}
  if(([uri]$download).Scheme -ne 'https' -or ([uri]$download).Host -notin @('upload.wikimedia.org','thumb.wikimedia.org')){return $null}
  if(([uri]$info.descriptionurl).Scheme -ne 'https' -or ([uri]$info.descriptionurl).Host -ne 'commons.wikimedia.org'){return $null}
  $artist=[Net.WebUtility]::HtmlDecode(([string]$meta.Artist.value -replace '<[^>]*>','')) -replace '\s+',' '
  if(!$artist){$artist='Commons contributor'}
  if($artist.Length -gt 70){$artist=$artist.Substring(0,67)+'...'}
  return @{id=('commons:'+$Page.pageid+':'+$info.sha1);url=[string]$info.descriptionurl;download=$download;photographer=$artist.Trim();source='Commons';license='CC0 1.0';licenseUrl='https://creativecommons.org/publicdomain/zero/1.0/';mime=$info.mime}
 }catch{return $null}
}
$CommonsHeaders=@{'User-Agent'='MotivationWallpaper/0.1 (https://github.com/rafeehcp/motivation-wallpaper)'}
function Get-CommonsCandidates($Folder,$Recent,$MinWidth,$MinHeight) {
 $catalog=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'commons-backgrounds.json') -Raw|ConvertFrom-Json
 $cachePath=Join-Path $Folder 'commons-metadata.json'
 $catalogCachePath=Join-Path $Folder 'commons-catalog-version.json'
 $pages=@()
 $allowed=@($catalog|ForEach-Object{$_.title})
 $catalogId=Get-QuoteId (($allowed|Sort-Object) -join '|')
 $cachedCatalog=$null
 if(Test-Path -LiteralPath $catalogCachePath){try{$cachedCatalog=Get-Content -LiteralPath $catalogCachePath -Raw|ConvertFrom-Json}catch{}}
 if((Test-Path -LiteralPath $cachePath) -and (Get-Item -LiteralPath $cachePath).LastWriteTime -gt (Get-Date).AddDays(-1) -and $cachedCatalog -and $cachedCatalog.PSObject.Properties['id'] -and $cachedCatalog.id -eq $catalogId){$loaded=Get-Content -LiteralPath $cachePath -Raw|ConvertFrom-Json;$pages=@($loaded)}
 else {
  $titles=($catalog|ForEach-Object{$_.title}) -join '|'
  $uri='https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2&prop=imageinfo&iiprop=url%7Csize%7Csha1%7Cmime%7Cextmetadata&iiurlwidth=3840&titles='+[uri]::EscapeDataString($titles)
  $response=Invoke-Service -Uri $uri -Headers $CommonsHeaders -TimeoutSeconds 10 -Attempts 1
  $pages=@($response.query.pages);Save-Json $cachePath $pages
  Save-Json $catalogCachePath @{id=$catalogId}
 }
 $candidates=@(foreach($page in $pages){if($page.title -in $allowed){$candidate=ConvertTo-CommonsCandidate $page $MinWidth $MinHeight;if($candidate -and $candidate.id -notin $Recent){
  $extension=if($candidate.mime -eq 'image/png'){'.png'}else{'.jpg'}
  $candidate.path=Join-Path $Folder ('commons_'+(Get-QuoteId $candidate.id)+'_'+$MinWidth+'x'+$MinHeight+$extension);$candidate
 }}})
 if(!$candidates.Count){throw 'No eligible unused Commons photo in the reviewed collection.'}
 return $candidates
}
function Save-CommonsPhoto($Photo,$MinWidth,$MinHeight) {
 # Downloads go to a separate name, so an interrupted transfer never looks like a saved photo.
 $partial=$Photo.path+'.partial'
 try {
  if(!(Test-Path -LiteralPath $Photo.path)){
   Invoke-Service -Uri $Photo.download -Headers $CommonsHeaders -OutFile $partial -TimeoutSeconds 10 -Attempts 1
   Move-Item -LiteralPath $partial -Destination $Photo.path
  }
  $image=[Drawing.Image]::FromFile($Photo.path)
  try{if($image.Width -lt $MinWidth -or $image.Height -lt $MinHeight){throw 'Downloaded photo is too small.'}}finally{$image.Dispose()}
 }catch{foreach($path in @($Photo.path,$partial)){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}};throw}
}
function Get-CommonsBackground($Folder,$Recent,$MinWidth,$MinHeight) {
 $candidates=Get-CommonsCandidates $Folder $Recent $MinWidth $MinHeight
 # Prefer a photo already on disk, such as one saved by Save-NextCommonsBackground.
 $saved=@($candidates|Where-Object{Test-Path -LiteralPath $_.path})
 $selected=if($saved.Count){$saved|Get-Random}else{$candidates|Get-Random}
 Save-CommonsPhoto $selected $MinWidth $MinHeight
 return $selected
}
# Called after a successful update, so the next update finds an unused photo already saved.
function Save-NextCommonsBackground($Folder,$Recent,$MinWidth,$MinHeight) {
 $candidates=Get-CommonsCandidates $Folder $Recent $MinWidth $MinHeight
 if(@($candidates|Where-Object{Test-Path -LiteralPath $_.path}).Count){return}
 Save-CommonsPhoto ($candidates|Get-Random) $MinWidth $MinHeight
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
