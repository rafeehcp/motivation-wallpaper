$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')
$testRoot=Join-Path $env:TEMP ('WallpaperPreferencesTests-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot|Out-Null
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}
try {
 $path=Join-Path $testRoot 'settings.json'
 Assert ((Get-WallpaperQuoteScreening $testRoot) -eq 'Basic') 'Missing screening defaults to Basic'
 Set-WallpaperQuoteScreening $testRoot 'Jev'
 Set-WallpaperShowCredits $testRoot $false
 Assert ((Get-WallpaperQuoteScreening $testRoot) -eq 'Jev' -and !(Get-WallpaperShowCredits $testRoot)) 'Credit changes preserve screening mode'
 Set-WallpaperQuoteScreening $testRoot 'Basic'
 Assert ((Get-WallpaperQuoteScreening $testRoot) -eq 'Basic' -and !(Get-WallpaperShowCredits $testRoot)) 'Screening changes preserve credit preference'
 Assert ((Get-WallpaperBackgroundSource $testRoot) -eq 'Commons') 'Missing background source defaults to Commons'
 Set-WallpaperBackgroundSource $testRoot 'Generated'
 Assert ((Get-WallpaperBackgroundSource $testRoot) -eq 'Generated' -and (Get-WallpaperQuoteScreening $testRoot) -eq 'Basic' -and !(Get-WallpaperShowCredits $testRoot)) 'Background source persists without changing other settings'
 Remove-Item -LiteralPath $path
 Assert (Get-WallpaperShowCredits $testRoot) 'Missing settings show source credits by default'
 Set-WallpaperShowCredits $testRoot $false
 Assert (!(Get-WallpaperShowCredits $testRoot)) 'Hidden credit preference persists as a Boolean'
 $parsed=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 Assert ($parsed.showCredits -is [bool] -and !$parsed.showCredits) 'Settings JSON stores false without string conversion'
 '{"showCredits":false,"other":{"value":"preserved"}}'|Set-Content -LiteralPath $path
 Set-WallpaperShowCredits $testRoot $true
 $parsed=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
 Assert ((Get-WallpaperShowCredits $testRoot) -and $parsed.other.value -eq 'preserved') 'Toggling credits preserves unrelated settings'
 Assert (Test-Path -LiteralPath "$path.previous") 'Atomic updates retain the previous settings file'
 foreach($invalid in @('{"showCredits":"false"}','[]','null','{broken')) {
  [IO.File]::WriteAllText($path,$invalid)
  Assert ((Get-WallpaperQuoteScreening $testRoot) -eq 'Basic') 'Invalid settings default to Basic screening'
  Assert ((Get-WallpaperBackgroundSource $testRoot) -eq 'Commons') 'Invalid settings default to Commons backgrounds'
  Assert (Get-WallpaperShowCredits $testRoot) 'Invalid or absent Boolean preference keeps source credits visible'
 }
 $before=[IO.File]::ReadAllText($path);$rejected=$false
 try{Set-WallpaperShowCredits $testRoot $false}catch{$rejected=$_.Exception.Message -like '*preserved*'}
 Assert ($rejected -and [IO.File]::ReadAllText($path) -ceq $before) 'Malformed settings are rejected without overwriting data'
 Remove-Item -LiteralPath $path
 . (Join-Path $PSScriptRoot 'ConfigureMotivationWallpaper.ps1') -DataDirectory $testRoot -HideCredits -ShowCredits
 $rejected=$false
 try{Configure-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*either*'}
 Assert ($rejected -and !(Test-Path -LiteralPath $path)) 'Conflicting options fail before creating settings or opening a dialog'
 $ShowCredits=$false;Configure-MotivationWallpaper|Out-Null
 Assert (!(Get-WallpaperShowCredits $testRoot)) 'Command-line hide option saves the preference without a dialog'
 $HideCredits=$false;$ShowCredits=$true;Configure-MotivationWallpaper|Out-Null
 Assert (Get-WallpaperShowCredits $testRoot) 'Command-line show option restores visible credits'
 $ShowCredits=$false;$QuoteScreening='Jev';Configure-MotivationWallpaper|Out-Null
 Assert ((Get-WallpaperQuoteScreening $testRoot) -eq 'Jev' -and (Get-WallpaperShowCredits $testRoot)) 'CLI screening choice preserves credits without a dialog'
 Remove-Variable QuoteScreening;$QuoteScreening='';$BackgroundSource='Generated';Configure-MotivationWallpaper|Out-Null
 Assert ((Get-WallpaperBackgroundSource $testRoot) -eq 'Generated' -and (Get-WallpaperQuoteScreening $testRoot) -eq 'Jev') 'CLI background choice saves without a dialog and preserves screening'
 # The window is built but never shown, so no desktop or credential dialog is needed.
 $saved=[IO.File]::ReadAllText($path)
 if(!('Motivation.AppIcon' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing}
 $appIcon=Join-Path $testRoot 'app.ico';[Motivation.AppIcon]::Save($appIcon)
 $window=New-WallpaperSettingsWindow $testRoot $appIcon;$ui=$script:settingsUi
 Assert ($null -ne $window.Icon) 'Settings window uses the installed app icon'
 Assert ($ui.Generated.IsChecked -and $ui.Jev.IsChecked -and $ui.Credits.IsChecked -and [IO.File]::ReadAllText($path) -ceq $saved) 'Settings window shows saved values without writing settings'
 $ui.Photos.IsChecked=$true;$ui.Credits.IsChecked=$false
 Assert ((Get-WallpaperBackgroundSource $testRoot) -eq 'Commons' -and !(Get-WallpaperShowCredits $testRoot)) 'Window choices save immediately'
 $script:messages=@()
 function Show-SettingsMessage($Message){$script:messages+=$Message}
 function Set-WallpaperCredentials {throw 'Credential setup cancelled.'}
 $ui.Basic.IsChecked=$true;$ui.Jev.IsChecked=$true
 Assert ($ui.Basic.IsChecked -and (Get-WallpaperQuoteScreening $testRoot) -eq 'Basic' -and $script:messages.Count -eq 1) 'Cancelled Jev key prompt returns the window to Basic'
 function Set-WallpaperCredentials {}
 $ui.Jev.IsChecked=$true
 Assert ((Get-WallpaperQuoteScreening $testRoot) -eq 'Jev') 'Jev saves once a key is available'
 Assert ((Get-WallpaperCaption (Join-Path $testRoot 'elsewhere.png')) -eq 'Set outside Motivation Wallpaper') 'Preview caption identifies wallpapers from other sources'
 $run=Join-Path $testRoot 'run';New-Item -ItemType Directory $run|Out-Null
 '{"theme":"Calm and reflective: balance","outputs":[{},{},{}]}'|Set-Content (Join-Path $run 'details.json')
 Assert ((Get-WallpaperCaption (Join-Path $run 'monitor_0.png')) -eq '3 monitors  |  Calm and reflective') 'Preview caption shows monitor count and theme'
 $failure="C:\App\SetMotivationWallpaper.ps1 : No quote passed quality checks. Wallpaper preserved.`r`n    + CategoryInfo          : NotSpecified"
 Assert ((Get-SettingsActionMessage $failure 'Using basic quote checks.') -eq 'No quote passed quality checks. Wallpaper preserved.') 'Background action errors show the script message'
 Assert ((Get-SettingsActionMessage '' "Using basic quote checks.`r`nAnother run is active; skipped.`r`n") -eq 'Another run is active; skipped.') 'Background actions without errors show their last output line'
 $window.Close()
}finally {
 $resolved=[IO.Path]::GetFullPath($testRoot)
 $temporaryRoot=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
 if($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'WallpaperPreferencesTests-*') {
  Remove-Item -LiteralPath $resolved -Recurse -Force
 }
}
