param([switch]$DesktopIntegration)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetMotivationWallpaper.ps1')
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}
$folder=Join-Path $env:TEMP ('QuoteScreeningTests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $folder|Out-Null
$valid=[pscustomobject]@{q='Small steps build steady progress.';a='Fixture author'}
Assert (Test-BasicQuote $valid) 'Readable quote passes Basic checks'
foreach($bad in @($null,[pscustomobject]@{q='Too short';a='Author'},[pscustomobject]@{q=('x'*231);a='Author'},[pscustomobject]@{q='This quote has no author.';a=' '},[pscustomobject]@{q="A quote with`ncontrol characters.";a='Author'},[pscustomobject]@{q='<b>Unwanted markup in text</b>';a='Author'},[pscustomobject]@{q='12345678901234567890';a='Author'},[pscustomobject]@{q='Visit https://example.com for more';a='Author'},[pscustomobject]@{q=@('Bad text','Bad text');a='Author'})) {
 Assert (!(Test-BasicQuote $bad)) 'Malformed candidate rejected'
}
Assert ((Repair-QuoteText "You Don'T Have To See The Whole Staircase, It'S Fine, I'M Here, We'Re Ready, You'Ll Win, I'D Go, They'Ve Won.") -eq "You Don't Have To See The Whole Staircase, It's Fine, I'm Here, We're Ready, You'll Win, I'd Go, They've Won.") 'Title-cased contractions repaired'
Assert ((Repair-QuoteText "Ask O'Brien and D'Angelo") -eq "Ask O'Brien and D'Angelo") 'Apostrophe names untouched'
Assert ((Repair-QuoteText 'Martin Luther King  Jr.') -eq 'Martin Luther King Jr.') 'Repeated spaces collapsed'
$script:candidates=@($valid,[pscustomobject]@{q='A quiet moment offers perspective.';a='Fixture author'})
$script:supplementCalls=0
function Get-Key {throw 'Basic must never request credentials'}
function Get-AssessmentBatch {throw 'Basic must never call Jev'}
function Read-Assessments {throw 'Basic must never read Jev cache'}
function Get-Candidates($Folder,[switch]$Supplemental){if($Supplemental){$script:supplementCalls++};return $script:candidates}
$chosen=Get-BasicQuote $folder 'Grounded and practical' @()
Assert ($chosen.q -eq $valid.q -and $script:supplementCalls -eq 0) 'Theme match preferred without supplemental request'
$chosen=Get-BasicQuote $folder 'Grounded and practical' @((Get-QuoteId $valid.q))
Assert ($chosen.q -ne $valid.q) 'Recent quote excluded with unmatched fallback'
$failed=$false
try{Get-BasicQuote $folder 'Grounded' @($script:candidates|ForEach-Object{Get-QuoteId $_.q})|Out-Null}catch{$failed=$_.Exception.Message -like '*Wallpaper preserved*'}
Assert $failed 'Exhausted candidates preserve wallpaper'
function Get-Candidates($Folder,[switch]$Supplemental){if($Supplemental){return $valid};return [pscustomobject]@{q='Short';a='Author'}}
Assert ((Get-BasicQuote $folder 'Grounded' @()).q -eq $valid.q) 'Supplemental source used when primary has no valid candidate'
if($DesktopIntegration){
 Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing
 $desktop=New-Object Motivation.Desktop
 try {
  $monitors=@($desktop.Monitors());$before=@($monitors|ForEach-Object{$desktop.Get($_.Id)})|ConvertTo-Json -Compress
  $DataDirectory=$folder;$PreviewOnly=$true;$Demo=$false;$Automatic=$false;$BackgroundSource='Generated';Remove-Variable QuoteScreening;$QuoteScreening=''
  function Get-Background($Folder,$Recent,$Width,$Height,$Theme){return Get-GeneratedBackground $Folder $Theme $Width $Height}
  Invoke-Wallpaper
  $details=Get-Content (Get-ChildItem $folder -Filter details.json -Recurse|Select-Object -First 1).FullName -Raw|ConvertFrom-Json
  Assert ($details.quoteScreening -eq 'Basic' -and $null -eq $details.assessment -and @($details.outputs).Count -eq $monitors.Count) 'Default Basic preview renders all monitors without Jev or key'
  $QuoteScreening='Jev';$failed=$false
  try{Invoke-Wallpaper}catch{$failed=$_.Exception.Message -like '*credentials*'}
  Assert $failed 'Explicit Jev override requires key and never falls back'
  Set-WallpaperQuoteScreening $folder 'Jev'
  Remove-Variable QuoteScreening;$QuoteScreening=''
  $failed=$false;try{Invoke-Wallpaper}catch{$failed=$_.Exception.Message -like '*credentials*'}
  Assert $failed 'Saved Jev selection is honored without a command-line override'
  $QuoteScreening='Basic';Invoke-Wallpaper
  Assert ((Get-WallpaperQuoteScreening $folder) -eq 'Jev') 'One-run Basic override preserves the saved Jev selection'
  $after=@($monitors|ForEach-Object{$desktop.Get($_.Id)})|ConvertTo-Json -Compress
  Assert ($before -eq $after) 'Previews and failures preserve current desktop'
 }finally{$desktop.Dispose()}
}
Write-Output "Fixtures: $folder"
