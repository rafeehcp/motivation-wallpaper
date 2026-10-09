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
 Assert ((Get-WallpaperQuotePosition $testRoot) -eq 'Center') 'Missing quote position keeps the original centered layout'
 Set-WallpaperQuotePosition $testRoot 'Right'
 Assert ((Get-WallpaperQuotePosition $testRoot) -eq 'Right' -and (Get-WallpaperBackgroundSource $testRoot) -eq 'Generated' -and !(Get-WallpaperShowCredits $testRoot)) 'Quote position persists without changing other settings'
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
  Assert ((Get-WallpaperQuotePosition $testRoot) -eq 'Center') 'Invalid settings default to the centered quote'
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
 Remove-Variable BackgroundSource;$BackgroundSource='';$QuotePosition='Left';Configure-MotivationWallpaper|Out-Null
 Assert ((Get-WallpaperQuotePosition $testRoot) -eq 'Left' -and (Get-WallpaperBackgroundSource $testRoot) -eq 'Generated') 'CLI quote position saves without a dialog and preserves the background'
 # The window is built but never shown, so no desktop or credential dialog is needed.
 $saved=[IO.File]::ReadAllText($path)
 if(!('Motivation.AppIcon' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing}
 $appIcon=Join-Path $testRoot 'app.ico';[Motivation.AppIcon]::Save($appIcon)
 $window=New-WallpaperSettingsWindow $testRoot $appIcon;$ui=$script:settingsUi
 Assert ($null -ne $window.Icon) 'Settings window uses the installed app icon'
 Assert ($ui.Generated.IsChecked -and $ui.Jev.IsChecked -and $ui.PositionLeft.IsChecked -and !$ui.PositionCenter.IsChecked -and $ui.Credits.IsChecked -and [IO.File]::ReadAllText($path) -ceq $saved) 'Settings window shows saved values without writing settings'
 Assert ($ui.Update.Visibility -eq 'Collapsed' -and !$ui.ContainsKey('Latest')) 'Settings window starts without an update button or release request'
 $height=$window.Content.Height;Show-SettingsUpdate '0.1.5'
 Assert ($ui.Update.Visibility -eq 'Visible' -and $ui.UpdateLabel.Text -eq 'Update to v0.1.5' -and $window.Content.Height -gt $height) 'A newer release shows its update button and grows the window to fit'
 $ui.Photos.IsChecked=$true;$ui.Credits.IsChecked=$false;$ui.PositionRight.IsChecked=$true
 Assert ((Get-WallpaperBackgroundSource $testRoot) -eq 'Commons' -and !(Get-WallpaperShowCredits $testRoot) -and (Get-WallpaperQuotePosition $testRoot) -eq 'Right') 'Window choices save immediately'
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
 function Start-Process($FilePath,$ArgumentList){$script:launch=@{file=$FilePath;arguments=$ArgumentList}}
 $script:closed=$false;$window.add_Closed({$script:closed=$true});$ui.Installation=[pscustomobject]@{taskName=''}
 $ui.Update.RaiseEvent((New-Object Windows.RoutedEventArgs ([Windows.Controls.Button]::ClickEvent)))
 $command=[Text.Encoding]::Unicode.GetString([Convert]::FromBase64String(($script:launch.arguments -split ' ')[-1]))
 Assert ((Test-Path -LiteralPath $script:launch.file -PathType Leaf) -and $command -eq (Get-WallpaperUpdateCommand $PSScriptRoot $true) -and $script:closed) 'Update click opens a console running the update command and closes the window'
 Remove-Item Function:\Start-Process
 Assert ((Get-WallpaperUpdateVersion '0.1.4' 'v0.1.5') -eq '0.1.5') 'A newer release tag is offered as an update'
 Assert ((Get-WallpaperUpdateVersion '0.1.4' '0.2') -eq '0.2') 'Release tags without a v prefix are compared'
 foreach($tag in 'v0.1.4','v0.1.3','latest',''){Assert ((Get-WallpaperUpdateVersion '0.1.4' $tag) -eq '') "Release tag '$tag' offers no update"}
 Assert ((Get-WallpaperUpdateVersion '' 'v0.1.5') -eq '') 'An unknown installed version offers no update'
 $directory=Join-Path $testRoot "O'Brien Apps\Motivation Wallpaper";$record=Join-Path $testRoot 'update.json';$started=Join-Path $testRoot 'started.txt'
 foreach($noSchedule in $true,$false) {
  Remove-Item -LiteralPath $record,$started -ErrorAction SilentlyContinue
  # Stubbing the cmdlet name also captures irm, an alias that would outrank a function named irm.
  $stubs="function Invoke-RestMethod(`$Uri){`"param([string]```$InstallDirectory,[switch]```$NoSchedule)@{uri='`$Uri';directory=```$InstallDirectory;noSchedule=[bool]```$NoSchedule}|ConvertTo-Json|Set-Content -LiteralPath '$record'`"}`nfunction Start-Process(`$FilePath){Set-Content -LiteralPath '$started' -Value `$FilePath}`n"
  $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($stubs+(Get-WallpaperUpdateCommand $directory $noSchedule)))
  & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded|Out-Null
  $run=Get-Content -LiteralPath $record -Raw|ConvertFrom-Json
  Assert ($run.uri -eq 'https://github.com/rafeehcp/motivation-wallpaper/releases/latest/download/Install.ps1' -and $run.directory -eq $directory -and $run.noSchedule -eq $noSchedule) "Update command reinstalls into the same quoted directory with NoSchedule $noSchedule"
  Assert ((Get-Content -LiteralPath $started -Raw).Trim() -eq (Join-Path $directory 'MotivationWallpaperSettings.exe')) 'Update command reopens Wallpaper Settings after setup'
 }
}finally {
 $resolved=[IO.Path]::GetFullPath($testRoot)
 $temporaryRoot=[IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')+'\'
 if($resolved.StartsWith($temporaryRoot,[StringComparison]::OrdinalIgnoreCase) -and (Split-Path $resolved -Leaf) -like 'WallpaperPreferencesTests-*') {
  Remove-Item -LiteralPath $resolved -Recurse -Force
 }
}
