$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1')
$DataDirectory=Join-Path $env:TEMP ('WallpaperRefresh-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $DataDirectory|Out-Null
$PreviewOnly=$true;$Automatic=$false;$Demo=$false;$QuoteScreening='Jev'
Save-Json (Join-Path $DataDirectory 'quotes-cache.json') @(@{q='Unsuited cached quote number one.';a='Fixture'},@{q='Unsuited cached quote number two.';a='Fixture'})
function Get-Key {return 'fixture-only'}
$script:fetches=0
function Invoke-Service {$script:fetches++;return @{quotes=@([pscustomobject]@{quote='Fresh suitable quote from the internet.';author='Fixture'})}}
function Get-Assessment($Quote,$Theme,$Key){
 $score=if($Quote.q -like 'Fresh*'){4}else{1};$answers=@{}
 foreach($name in @('clarity','motivation','theme')){$p=@{'0'=0;'1'=0;'2'=0;'3'=0;'4'=0};$p[[string]$score]=1;$answers[$name]=@{type='score';score=$score;confidence=1;probabilities=$p}}
 return @{answers=$answers}
}
function Get-AssessmentBatch($Quotes,$Theme,$Key,$Cache,$Folder){$result=@{};foreach($q in $Quotes){$result[(Get-QuoteId $q.q)]=Get-Assessment $q $Theme $Key};return $result}
function Get-Background {return @{id='fixture';path='';photographer='Fixture';url=''}}
Invoke-Wallpaper
$details=Get-ChildItem $DataDirectory -Filter details.json -Recurse|Select-Object -First 1
if(!$details){throw 'FAIL: no new wallpaper generated after cached candidates were rejected.'}
$rendered=Get-Content $details.FullName -Raw|ConvertFrom-Json
if($rendered.quote.q -ne 'Fresh suitable quote from the internet.' -or $script:fetches -ne 1){throw 'FAIL: did not recover by fetching a fresh batch.'}
Write-Output 'PASS: rejected cache refreshes once and produces a new approved wallpaper.'
# Quotes Jev approved before the text repair existed come back from its cache unrepaired.
$DataDirectory=Join-Path $env:TEMP ('WallpaperRefresh-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $DataDirectory|Out-Null
$approved=Get-Assessment ([pscustomobject]@{q='Fresh'}) '' ''
function Read-Assessments {$cache=@{};foreach($theme in @('Grounded and practical: discipline, progress, resilience','Bold and ambitious: achievement, ambition, effort','Calm and reflective: balance, patience, purpose')){$cache[$theme]=[pscustomobject]@{theme=$theme;quote=[pscustomobject]@{q="I Don'T Know Who My Grandfather Was.";a='Martin Luther King  Jr.';source='dummyjson.com'};assessment=$approved}};return $cache}
Invoke-Wallpaper
$rendered=Get-Content (Get-ChildItem $DataDirectory -Filter details.json -Recurse|Select-Object -First 1).FullName -Raw|ConvertFrom-Json
if($rendered.quote.q -cne "I Don't Know Who My Grandfather Was." -or $rendered.quote.a -cne 'Martin Luther King Jr.'){throw "FAIL: cached Jev quote rendered unrepaired: $($rendered.quote.q) / $($rendered.quote.a)"}
Write-Output 'PASS: a quote from the Jev cache is repaired before rendering.'
