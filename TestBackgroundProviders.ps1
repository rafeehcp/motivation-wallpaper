$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1')
if(!('Motivation.Renderer' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing}
$folder=Join-Path $env:TEMP ('WallpaperBackgroundTests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $folder|Out-Null
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Host "PASS: $Message"}
$page=@{
 pageid=123;title='File:Landscape of a wild forest.jpg';imageinfo=@(@{
  url='https://upload.wikimedia.org/test/photo.jpg';descriptionurl='https://commons.wikimedia.org/wiki/File:Landscape_of_a_wild_forest.jpg';sha1='fixture';mime='image/jpeg';size=500000;width=4000;height=3000
  thumburl='https://thumb.wikimedia.org/test/photo.jpg';thumbwidth=3840;thumbheight=2880
  extmetadata=@{LicenseShortName=@{value='CC0'};LicenseUrl=@{value='https://creativecommons.org/publicdomain/zero/1.0/'};Artist=@{value='<a>Test &amp; artist</a>'}}
 })
}|ConvertTo-Json -Depth 10|ConvertFrom-Json
$candidate=ConvertTo-CommonsCandidate $page 1920 1920
Assert ($candidate -and $candidate.photographer -eq 'Test & artist' -and $candidate.download -like '*thumb.wikimedia.org*') 'CC0 photo uses adequate thumbnail and plain text author credit'
$page.imageinfo[0].extmetadata.LicenseUrl.value='http://creativecommons.org/publicdomain/zero/1.0/deed.en'
Assert ($null -ne (ConvertTo-CommonsCandidate $page 1920 1920)) 'Commons language-specific CC0 deed URL is accepted'
$page.imageinfo[0].extmetadata.LicenseShortName.value='CC BY-SA 4.0'
Assert ($null -eq (ConvertTo-CommonsCandidate $page 1920 1920)) 'Other licenses are excluded from CC0-only collection'
$page.imageinfo[0].extmetadata.LicenseShortName.value='CC0';$page.imageinfo[0].extmetadata.LicenseUrl.value='https://example.com/cc0'
Assert ($null -eq (ConvertTo-CommonsCandidate $page 1920 1920)) 'Unverified license URL is rejected'
$page.imageinfo[0].extmetadata.LicenseUrl.value='https://creativecommons.org/publicdomain/zero/1.0/';$page.imageinfo[0].height=1000
Assert ($null -eq (ConvertTo-CommonsCandidate $page 1920 1920)) 'Insufficient original resolution is rejected'
$page.imageinfo[0].height=3000;$page.imageinfo[0].thumburl='https://example.com/photo.jpg'
Assert ($null -eq (ConvertTo-CommonsCandidate $page 1920 1920)) 'Downloads are restricted to Wikimedia image hosts'
$page.imageinfo[0].thumburl='https://thumb.wikimedia.org/test/photo.jpg'
$script:metadataCalls=0;$script:downloads=0
function Invoke-Service($Uri,$Headers,$Body,$OutFile,$TimeoutSeconds,$Attempts){
 Assert ($Headers['User-Agent'] -like 'MotivationWallpaper/*' -and $TimeoutSeconds -eq 10 -and $Attempts -eq 1) 'Commons requests identify application and bound fallback wait'
 if($OutFile){$script:downloads++;[Motivation.Renderer]::GenerateBackground($OutFile,1920,1920,'Calm',1);return}
 $script:metadataCalls++;return @{query=@{pages=@($page,[pscustomobject]@{pageid=999;title='File:Not in reviewed collection.jpg'})}}
}
$photo=Get-CommonsBackground $folder @() 1920 1920
$again=Get-CommonsBackground $folder @() 1920 1920
Assert ($photo.id -eq $again.id -and $script:metadataCalls -eq 1 -and $script:downloads -eq 1) 'Metadata and validated downloads are cached'
Save-Json (Join-Path $folder 'commons-catalog-version.json') @{id='earlier-catalog'}
$refreshed=Get-CommonsBackground $folder @() 1920 1920
$cachedAgain=Get-CommonsBackground $folder @() 1920 1920
Assert ($script:metadataCalls -eq 2 -and $script:downloads -eq 1 -and $refreshed.id -eq $cachedAgain.id) 'An expanded catalog refreshes metadata once without downloading a cached photo again'
$rejected=$false;try{Get-CommonsBackground $folder @($photo.id) 1920 1920}catch{$rejected=$true}
Assert $rejected 'Recently used Commons photo is excluded'
$BackgroundSource='Commons';$Automatic=$true
$fallback=Get-Background $folder @($photo.id) 1920 1920 'Calm and reflective'
Assert ($fallback.source -eq 'Generated' -and (Test-Path $fallback.path)) 'Exhausted photo collection produces original background'
function Invoke-Service {throw 'Simulated network outage.'}
$offlineFolder=Join-Path $folder 'offline';New-Item -ItemType Directory $offlineFolder|Out-Null
$offline=Get-Background $offlineFolder @() 1920 1920 'Bold and ambitious'
Assert ($offline.source -eq 'Generated') 'Commons outage falls back without blocking quote rendering'
$BackgroundSource='Generated'
$next=Get-Background $folder @($fallback.id) 1920 1920 'Calm and reflective'
Assert ($next.id -ne $fallback.id -and $next.path -ne $fallback.path) 'Generated backgrounds have fresh identities and filenames'
Assert ((Get-BackgroundHtml $photo).Contains('creativecommons.org/publicdomain/zero/1.0/') -and (Get-BackgroundHtml $fallback).Contains('Original generated background')) 'Preview attribution follows selected source'
$index=0
foreach($theme in @('Grounded and practical','Bold and ambitious','Calm and reflective')){
 foreach($dimensions in @(@(1920,1080),@(1080,1920))){
  $background=Get-GeneratedBackground $folder $theme $dimensions[0] $dimensions[1]
  $output=Join-Path $folder "sample_$index.png"
  $null=[Motivation.Renderer]::Render($background.path,$output,$dimensions[0],$dimensions[1],'Small steps, taken consistently, can carry you a long way.','Layout demonstration','ORIGINAL GENERATED BACKGROUND',$theme)
  $image=[Drawing.Image]::FromFile($output)
  try{Assert ($image.Width -eq $dimensions[0] -and $image.Height -eq $dimensions[1]) "Generated wallpaper rendered: $theme / $($dimensions -join 'x')"}finally{$image.Dispose()}
  $index++
 }
}
Write-Output "Background samples ready: $folder"
