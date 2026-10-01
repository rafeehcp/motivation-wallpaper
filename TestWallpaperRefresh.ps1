$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1')
$DataDirectory=Join-Path $env:TEMP ('WallpaperRefresh-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $DataDirectory|Out-Null
$PreviewOnly=$true;$Automatic=$false;$Demo=$false
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
