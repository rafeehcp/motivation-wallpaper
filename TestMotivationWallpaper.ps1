param([switch]$DesktopIntegration)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1')
$testFolder=Join-Path $env:TEMP ('WallpaperTests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $testFolder|Out-Null
$script:passed=0
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};$script:passed++;Write-Output "PASS: $Message"}
Assert ((Get-QuoteId 'Keep going!') -eq (Get-QuoteId ' keep GOING. ')) 'Quote normalization catches case and punctuation repeats'
$answers=@{};foreach($name in @('clarity','motivation','theme')){$answers[$name]=@{type='score';score=3.5;confidence=.5;probabilities=@{'0'=0;'1'=0;'2'=0;'3'=.5;'4'=.5}}}
Assert (Test-Assessment @{answers=$answers}) 'Accept qualifying assessment'
Assert (Test-Assessment @{answers=$answers}) 'Accept uncertainty between good and excellent'
$answers.theme.probabilities=@{'0'=0;'1'=0;'2'=.3;'3'=0;'4'=.7};Assert (!(Test-Assessment @{answers=$answers})) 'Reject high mean when acceptable probability is below 80 percent'
$answers.theme.probabilities=@{'0'=0;'1'=0;'2'=0;'3'=.5;'4'=.5};$answers.theme.score=2.99;Assert (!(Test-Assessment @{answers=$answers})) 'Reject below 4/5'
$answers.theme.score=[double]::NaN;Assert (!(Test-Assessment @{answers=$answers})) 'Reject nonfinite scores'
$answers.theme.score=3.5;$answers.theme.probabilities=@{'3'=1};Assert (!(Test-Assessment @{answers=$answers})) 'Reject missing distribution levels'
$historyFile=Join-Path $testFolder 'history.json';Save-Json $historyFile @{entries=@(1..30)};Save-Json $historyFile @{entries=@(2..31)}
$loaded=Get-Content $historyFile -Raw|ConvertFrom-Json
Assert ($loaded.entries.Count -eq 30 -and $loaded.entries[0] -eq 2) 'Atomic state replacement persists rolling history'
# Check daily and overlap guards before any desktop/API call.
$DataDirectory=$testFolder;$Automatic=$true;$PreviewOnly=$false;$Demo=$false
Save-Json $historyFile @{entries=@();sequence=0;lastAutomaticDate=(Get-Date -Format 'yyyy-MM-dd')}
Assert ((Invoke-Wallpaper) -eq 'Already updated today.') 'Second daily invocation skips'
$held=[IO.File]::Open((Join-Path $testFolder 'run.lock'),'OpenOrCreate','ReadWrite','None')
try{Assert ((Invoke-Wallpaper) -eq 'Another run is active; skipped.') 'Concurrent invocation skips'}finally{$held.Dispose()}
$Demo=$true;$rejected=$false;try{Invoke-Wallpaper}catch{$rejected=$_.Exception.Message -match 'PreviewOnly'}
Assert $rejected 'Demo cannot apply unscreened wallpaper'
if(!('Motivation.Renderer' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing}
$samples=@('Small steps, taken consistently, can carry you a long way.','Set a meaningful goal, then give it your full effort.','Make room for patience, reflection, and the things that matter most.')
$index=0
foreach($quote in $samples){foreach($dimensions in @(@(1920,1080),@(1080,1920),@(1536,864))){
 $output=Join-Path $testFolder "sample_$index.png"
 $theme=@('Grounded and practical','Bold and ambitious','Calm and reflective')[[int][Math]::Floor($index/3)]
 $size=[Motivation.Renderer]::Render('',$output,$dimensions[0],$dimensions[1],$quote,'Layout sample','LAYOUT TEST - NOT SCREENED BY JEV',$theme)
 $image=[Drawing.Image]::FromFile($output)
 try{Assert ($image.Width -eq $dimensions[0] -and $image.Height -eq $dimensions[1] -and $size -ge ([Math]::Min($dimensions[0],$dimensions[1])*.034)) "Readable render: sample $index"}finally{$image.Dispose()};$index++
}}
$rejected=$false;try{[Motivation.Renderer]::Render('',(Join-Path $testFolder 'overflow.png'),1080,1920,('longword'*100),'Author','Test')}catch{$rejected=$true}
Assert $rejected 'Oversized text is rejected instead of clipped'
$originalService=${function:Invoke-Service}
try {
 $script:requests=0
 function Invoke-Service { $script:requests++;return @([pscustomobject]@{q='Keep making steady progress every day.';a='Test author'},[pscustomobject]@{q='Take time to reflect on what matters.';a='Test author'}) }
 $batch=@(Get-Candidates $testFolder);$cachedBatch=@(Get-Candidates $testFolder)
 Assert ($batch.Count -eq 2 -and $cachedBatch.Count -eq 2 -and $script:requests -eq 1) 'Online batch remains individual quotes and cache avoids another request'
}finally{Set-Item Function:Invoke-Service $originalService}
if($DesktopIntegration){
 $desktop=New-Object Motivation.Desktop
 try {
  $before=@($desktop.Monitors()|ForEach-Object{$desktop.Get($_.Id)})|ConvertTo-Json -Compress
  $Automatic=$false;$Demo=$false;$PreviewOnly=$false
  Save-Json $historyFile @{entries=@();sequence=0;lastAutomaticDate=''}
  $originalKey=${function:Get-Key};$originalCandidates=${function:Get-Candidates};$originalAssessment=${function:Get-Assessment};$originalBatch=${function:Get-AssessmentBatch}
  try{
   function Get-Key {throw 'Simulated missing credentials'}
   $failed=$false;try{Invoke-Wallpaper}catch{$failed=$_.Exception.Message -match 'Simulated missing'}
   Assert $failed 'Missing credential aborts before wallpaper changes'
   function Get-Key {return 'test-placeholder'}
   function Get-Candidates {throw 'Simulated network failure'}
   $failed=$false;try{Invoke-Wallpaper}catch{$failed=$_.Exception.Message -match 'Simulated network'}
   Assert $failed 'Unavailable quote source aborts safely'
   function Get-Candidates {return [pscustomobject]@{q='Test quote for rejection handling.';a='Test'}}
   function Get-Assessment {$a=@{};foreach($n in @('clarity','motivation','theme')){$a[$n]=@{type='score';score=1;confidence=.9}};return @{answers=$a}}
   function Get-AssessmentBatch($Quotes,$Theme,$Key,$Cache,$Folder){$result=@{};foreach($q in $Quotes){$result[(Get-QuoteId $q.q)]=Get-Assessment};return $result}
   $failed=$false;try{Invoke-Wallpaper}catch{$failed=$_.Exception.Message -match 'No quote passed'}
   Assert $failed 'Rejected quotes are never applied'
  }finally{Set-Item Function:Get-Key $originalKey;Set-Item Function:Get-Candidates $originalCandidates;Set-Item Function:Get-Assessment $originalAssessment;Set-Item Function:Get-AssessmentBatch $originalBatch}
  $after=@($desktop.Monitors()|ForEach-Object{$desktop.Get($_.Id)})|ConvertTo-Json -Compress
  Assert ($before -eq $after) 'All three monitor wallpapers survive failure scenarios unchanged'
  $state=Get-Content $historyFile -Raw|ConvertFrom-Json
  Assert ($state.entries.Count -eq 0 -and $state.sequence -eq 0) 'Failures do not advance theme or repeat history'
 }finally{$desktop.Dispose()}
}
Write-Output "$script:passed checks passed. Samples: $testFolder"
