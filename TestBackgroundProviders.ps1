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
$wide=$page|ConvertTo-Json -Depth 10|ConvertFrom-Json
$wide.imageinfo[0].width=4032;$wide.imageinfo[0].height=2432;$wide.imageinfo[0].thumbwidth=3840;$wide.imageinfo[0].thumbheight=2316
$wide.imageinfo[0].thumburl='https://thumb.wikimedia.org/thumb/5/5c/Sun.jpg/3840px-Sun.jpg'
Assert ((ConvertTo-CommonsCandidate $wide 1920 1080).download -like '*/1920px-Sun.jpg') 'Landscape monitors download the 1920 thumbnail when it covers them'
Assert ((ConvertTo-CommonsCandidate $wide 1920 1920).download -like '*/3840px-Sun.jpg') 'A portrait monitor keeps the 3840 thumbnail when 1920 would be too short'
$second=$page|ConvertTo-Json -Depth 10|ConvertFrom-Json
$second.pageid=456;$second.title='File:Sun in forest.jpg';$second.imageinfo[0].sha1='second'
$prefetchFolder=Join-Path $folder 'prefetch';New-Item -ItemType Directory $prefetchFolder|Out-Null
$script:prefetchPages=@($page,$second)
function Invoke-Service($Uri,$Headers,$Body,$OutFile,$TimeoutSeconds,$Attempts){
 if($OutFile){$script:downloads++;[Motivation.Renderer]::GenerateBackground($OutFile,1920,1920,'Calm',1);return}
 return @{query=@{pages=$script:prefetchPages}}
}
$script:downloads=0
Save-NextCommonsBackground $prefetchFolder @() 1920 1920
Save-NextCommonsBackground $prefetchFolder @() 1920 1920
Assert ($script:downloads -eq 1 -and @(Get-ChildItem $prefetchFolder -Filter 'commons_*').Count -eq 1 -and @(Get-ChildItem $prefetchFolder -Filter '*.partial').Count -eq 0) 'Saving the next photo downloads one photo once and leaves no partial file'
# Compare names: Get-ChildItem expands 8.3 short folder names (CI's TEMP is C:\Users\RUNNER~1\...)
# while the providers keep the path they were given.
$saved=(Get-ChildItem $prefetchFolder -Filter 'commons_*').Name
$picks=@(1..8|ForEach-Object{Get-CommonsBackground $prefetchFolder @() 1920 1920});$used=$picks[0]
Assert (@($picks|Where-Object{[IO.Path]::GetFileName($_.path) -ne $saved}).Count -eq 0 -and $script:downloads -eq 1) 'The next update uses the saved photo without downloading'
Save-NextCommonsBackground $prefetchFolder @($used.id) 1920 1920
Assert ($script:downloads -eq 2 -and @(Get-ChildItem $prefetchFolder -Filter 'commons_*').Count -eq 2) 'After that photo is used, the next unused photo is saved'
function Invoke-Service($Uri,$Headers,$Body,$OutFile,$TimeoutSeconds,$Attempts){
 if($OutFile){Set-Content -LiteralPath $OutFile -Value 'half a jpeg';throw 'Simulated dropped connection.'}
 return @{query=@{pages=$script:prefetchPages}}
}
$interruptedFolder=Join-Path $folder 'interrupted';New-Item -ItemType Directory $interruptedFolder|Out-Null
$failed=$false;try{Save-NextCommonsBackground $interruptedFolder @() 1920 1920}catch{$failed=$true}
Assert ($failed -and @(Get-ChildItem $interruptedFolder -Filter 'commons_*').Count -eq 0) 'An interrupted download leaves nothing that looks like a saved photo'
$killedFolder=Join-Path $folder 'killed';New-Item -ItemType Directory $killedFolder|Out-Null
$job=Start-Job -ArgumentList $PSScriptRoot,$killedFolder,($script:prefetchPages|ConvertTo-Json -Depth 10) -ScriptBlock {
 param($Repo,$Folder,$PagesJson)
 . (Join-Path $Repo 'SetMotivationWallpaper.ps1')
 $script:pages=$PagesJson|ConvertFrom-Json
 function Invoke-Service($Uri,$Headers,$Body,$OutFile,$TimeoutSeconds,$Attempts){
  if($OutFile){Set-Content -LiteralPath $OutFile -Value 'half a jpeg';Start-Sleep -Seconds 60;return}
  return @{query=@{pages=$script:pages}}
 }
 Save-NextCommonsBackground $Folder @() 1920 1920
}
$deadline=(Get-Date).AddSeconds(60)
while(!(Get-ChildItem $killedFolder -Filter 'commons_*') -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 200}
Stop-Job $job;Remove-Job $job -Force
Assert (@(Get-ChildItem $killedFolder -Filter 'commons_*').Count -eq 1) 'The killed download left its file behind'
function Invoke-Service($Uri,$Headers,$Body,$OutFile,$TimeoutSeconds,$Attempts){
 if($OutFile){$script:downloads++;[Motivation.Renderer]::GenerateBackground($OutFile,1920,1920,'Calm',1);return}
 return @{query=@{pages=$script:prefetchPages}}
}
$before=$script:downloads
Save-NextCommonsBackground $killedFolder @() 1920 1920
Assert ($script:downloads -eq $before+1) 'A download killed partway is not mistaken for a saved photo'
$DataDirectory=$folder;Remove-Variable BackgroundSource;$BackgroundSource=''
Assert ((Get-RunBackgroundSource) -eq 'Commons') 'Runs without a saved or explicit source use Commons'
Set-WallpaperBackgroundSource $folder 'Generated'
Assert ((Get-RunBackgroundSource) -eq 'Generated') 'Runs without an explicit source use the saved setting'
$BackgroundSource='Commons'
Assert ((Get-RunBackgroundSource) -eq 'Commons') 'Explicit source overrides the saved setting for one run'
$Automatic=$true
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
