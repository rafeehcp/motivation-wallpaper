$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1')
$folder=Join-Path $env:TEMP ('WallpaperBatch-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory $folder|Out-Null
$script:requests=0
function Invoke-Service($Uri,$Headers,$Body){
 $script:requests++;$answers=@{}
 foreach($id in $Body.questions.Keys){
  $score=if($Body.questions[$id].instructions.quote -eq 'Quote number 0'){4}else{1}
  $p=@{'0'=0;'1'=0;'2'=0;'3'=0;'4'=0};$p[[string]$score]=1
  $answers[$id]=@{type='score';score=$score;confidence=1;probabilities=$p}
 }
 return @{model='jev-1.13.0';answers=$answers}
}
$quotes=@(0..9|ForEach-Object{[pscustomobject]@{q="Quote number $_";a='Test'}})
$cache=Read-Assessments $folder
$result=Get-AssessmentBatch $quotes 'Practical' 'fixture' $cache $folder
if($script:requests -ne 1 -or $result.Count -ne 10){throw 'FAIL: ten quotes must use one request.'}
if(!(Test-Assessment $result[(Get-QuoteId $quotes[0].q)]) -or (Test-Assessment $result[(Get-QuoteId $quotes[1].q)])){throw 'FAIL: batch mixed up quote decisions.'}
$cache=Read-Assessments $folder
$result=Get-AssessmentBatch $quotes 'Practical' 'fixture' $cache $folder
if($script:requests -ne 1){throw 'FAIL: restart must reuse accepted and rejected decisions.'}
$result=Get-AssessmentBatch $quotes 'Reflective' 'fixture' $cache $folder
if($script:requests -ne 2){throw 'FAIL: a different theme must get a separate assessment.'}
Write-Output 'PASS: 10 quotes in one call, decisions mapped correctly, cache survives reload, themes isolated.'
