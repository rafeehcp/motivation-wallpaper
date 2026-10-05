$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetupMotivationWallpaper.ps1')
. (Join-Path $PSScriptRoot 'UninstallMotivationWallpaper.ps1')
$registerImplementation=${function:Register-WallpaperTask}
$removeImplementation=${function:Remove-WallpaperTask}
$testRoot=Join-Path $env:TEMP ('MotivationInstallTests-'+[guid]::NewGuid().ToString('N'))
$script:testDesktop=Join-Path $testRoot 'Desktop'
New-Item -ItemType Directory -Path $script:testDesktop -Force|Out-Null
function Get-WallpaperDesktopPath {return $script:testDesktop}
$script:testStartMenu=Join-Path $testRoot 'Start Menu'
New-Item -ItemType Directory -Path $script:testStartMenu -Force|Out-Null
function Get-WallpaperStartMenuPath {return $script:testStartMenu}
$script:savedSource=''
function Set-WallpaperBackgroundSource($Folder,$BackgroundSource){$script:savedSource=$BackgroundSource}
$script:credentialCalls=0;$script:savedMode='Basic'
function Set-WallpaperCredentials {$script:credentialCalls++}
function Get-WallpaperQuoteScreening {return $script:savedMode}
function Set-WallpaperQuoteScreening($Folder,$QuoteScreening){$script:savedMode=$QuoteScreening}
$script:schedules=0;$script:removed=0
function Register-WallpaperTask($ScriptPath,$Directory){$script:schedules++}
function Remove-WallpaperTask($Name,$ScriptPath){$script:removed++}
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}
$InstallDirectory=[IO.Path]::GetFullPath((Join-Path $testRoot ('App with spaces '+[char]0x00e9))).TrimEnd('\');$NoSchedule=$true;$CredentialsOnly=$false
Install-MotivationWallpaper
$launcher=Join-Path $script:testDesktop 'Change Wallpaper.cmd'
Assert (!(Test-Path $launcher) -and $script:schedules -eq 0) 'Manual-only installation creates no Change Wallpaper.cmd and no schedule'
Assert (!$script:savedSource -and (Test-Path (Join-Path $InstallDirectory 'commons-backgrounds.json'))) 'Installation includes Commons collection and leaves background source to saved settings'
$settingsScript=Join-Path $InstallDirectory 'ConfigureMotivationWallpaper.ps1'
$shortcuts=@((Join-Path $script:testDesktop 'Wallpaper Settings.lnk'),(Join-Path $script:testStartMenu 'Motivation Wallpaper Settings.lnk'))
Assert (@($shortcuts|Where-Object{(Test-Path -LiteralPath $_) -and (Test-WallpaperShortcutOwner $_ $settingsScript)}).Count -eq 2) 'Desktop and Start menu settings shortcuts open the installed settings window'
Assert ((Test-Path (Join-Path $InstallDirectory 'WallpaperStorage.ps1')) -and (Test-Path (Join-Path $InstallDirectory 'WallpaperPreferences.ps1')) -and (Test-Path $settingsScript)) 'Installation includes cleanup and saved settings configuration'
$fixtureSettings=$settingsScript
@("'ok' | Set-Content (Join-Path `$PSScriptRoot 'settings-result.txt')",'exit 0')|Set-Content -LiteralPath $fixtureSettings -Encoding ASCII
# A GUI-subsystem launcher (PE subsystem 2) never opens a console window of its own.
$settingsLauncher=Join-Path $InstallDirectory 'MotivationWallpaperSettings.exe'
$bytes=[IO.File]::ReadAllBytes($settingsLauncher);$subsystem=[BitConverter]::ToUInt16($bytes,[BitConverter]::ToInt32($bytes,0x3C)+0x5C)
$appIcon=Join-Path $InstallDirectory 'MotivationWallpaper.ico'
Add-Type -AssemblyName PresentationCore,System.Drawing
$frames=[Windows.Media.Imaging.BitmapDecoder]::Create([Uri]$appIcon,[Windows.Media.Imaging.BitmapCreateOptions]::None,[Windows.Media.Imaging.BitmapCacheOption]::OnLoad).Frames
Assert (@($frames|ForEach-Object{$_.PixelWidth}) -contains 256 -and @($frames|ForEach-Object{$_.PixelWidth}) -contains 16 -and @($shortcuts|Where-Object{(New-Object -ComObject WScript.Shell).CreateShortcut($_).IconLocation -eq "$appIcon,0"}).Count -eq 2) 'Setup draws a multi-size app icon that both shortcuts use'
$small=(New-Object Drawing.Icon($appIcon,16,16)).ToBitmap().GetPixel(8,3)
Assert ($small.B -gt $small.R+80) 'Small icon sizes decode as images in System.Drawing, not raw bytes'
# The sky at the top of the icon is blue; the default executable icon is not.
$top=[Drawing.Icon]::ExtractAssociatedIcon((Join-Path $InstallDirectory 'MotivationWallpaperSettings.exe')).ToBitmap().GetPixel(16,6)
Assert ($top.B -gt $top.R+80) 'The settings launcher carries the app icon'
Assert ($subsystem -eq 2 -and @($shortcuts|Where-Object{$link=(New-Object -ComObject WScript.Shell).CreateShortcut($_);$link.TargetPath -eq $settingsLauncher -and !$link.Arguments}).Count -eq 2) 'Settings shortcuts run the windowless launcher'
Start-Process -FilePath $settingsLauncher -Wait
$deadline=(Get-Date).AddSeconds(15);while(!(Test-Path (Join-Path $InstallDirectory 'settings-result.txt')) -and (Get-Date) -lt $deadline){Start-Sleep -Milliseconds 200}
Assert (Test-Path (Join-Path $InstallDirectory 'settings-result.txt')) 'Windowless launcher starts the installed settings script from a Unicode path'
Install-MotivationWallpaper
Assert ($script:schedules -eq 0 -and $script:credentialCalls -eq 0) 'Repeated Basic setup never requests credentials'
$QuoteScreening='Jev';Install-MotivationWallpaper
Assert ($script:credentialCalls -eq 1 -and $script:savedMode -eq 'Jev') 'Explicit Jev setup requests credentials and persists selection'
Remove-Variable QuoteScreening;$QuoteScreening='';Install-MotivationWallpaper
Assert ($script:credentialCalls -eq 2) 'Setup preserves saved Jev selection'
$QuoteScreening='Basic';Install-MotivationWallpaper
Assert ($script:credentialCalls -eq 2 -and $script:savedMode -eq 'Basic') 'Explicit Basic setup skips credentials and persists selection'
Remove-Variable QuoteScreening;$QuoteScreening=''
$BackgroundSource='Generated';Install-MotivationWallpaper
Assert ($script:savedSource -eq 'Generated') 'Explicit setup background source is saved as a setting'
Remove-Variable BackgroundSource;$BackgroundSource=''
$NoSchedule=$false;Install-MotivationWallpaper
Assert ($script:schedules -eq 1) 'Scheduled setup requests task registration'
$NoSchedule=$true;Install-MotivationWallpaper
$manifestPath=Join-Path $InstallDirectory 'installation.json'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
Assert ($manifest.taskName -eq 'MotivationWallpaper') 'Manual-only rerun retains ownership of previous schedule'
$oldLauncher=@('@echo off','rem MotivationWallpaper managed launcher',('powershell.exe -File "'+(Join-Path $InstallDirectory 'SetMotivationWallpaper.ps1')+'"'))
$oldLauncher|Set-Content -LiteralPath $launcher -Encoding UTF8
$manifest|Add-Member NoteProperty launcher $launcher -Force;$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
Install-MotivationWallpaper
Assert (!(Test-Path $launcher) -and !((Get-Content $manifestPath -Raw|ConvertFrom-Json).PSObject.Properties['launcher'])) 'Upgrade removes the managed Change Wallpaper.cmd from earlier releases'
'Unrelated launcher'|Set-Content $launcher
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
$manifest|Add-Member NoteProperty launcher $launcher -Force;$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
Install-MotivationWallpaper
Assert ((Get-Content $launcher) -eq 'Unrelated launcher') 'Upgrade leaves a recorded but unrelated Change Wallpaper.cmd alone'
$oldLauncher|Set-Content -LiteralPath $launcher -Encoding UTF8
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
$manifest|Add-Member NoteProperty launcher $launcher -Force;$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
# Reject path traversal in an edited manifest before removing anything.
$manifest.files+=@('..\outside.txt');$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
$rejected=$false;try{Uninstall-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*Invalid installation file list*'}
Assert ($rejected -and (Test-Path $launcher) -and (Test-Path $manifestPath) -and $script:removed -eq 0) 'Invalid uninstall manifest preserves installation and task'
$manifest.files=@($manifest.files|Where-Object{$_ -ne '..\outside.txt'});$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
$retained=Join-Path $InstallDirectory 'personal-file.txt';'Keep me'|Set-Content $retained
Uninstall-MotivationWallpaper
Assert ((Test-Path $retained) -and !(Test-Path $launcher) -and !(Test-Path $appIcon) -and $script:removed -eq 1) 'Uninstall removes managed files, an earlier-release launcher, and the schedule but retains unrelated files'
Assert (@($shortcuts|Where-Object{Test-Path -LiteralPath $_}).Count -eq 0) 'Uninstall removes both settings shortcuts'
$InstallDirectory=Join-Path $testRoot 'OtherApp'
New-WallpaperShortcut $shortcuts[1] (Join-Path $testRoot 'Elsewhere')
$rejected=$false;try{Install-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*shortcut belongs*'}
Assert ($rejected -and !(Test-Path $InstallDirectory)) 'Setup refuses an unrelated settings shortcut before writing files'
Remove-Item -LiteralPath $shortcuts[1]
$InstallDirectory=Join-Path $testRoot 'Unmanaged';New-Item -ItemType Directory $InstallDirectory|Out-Null
$rejected=$false;try{Install-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*not managed*'}
Assert $rejected 'Setup refuses an unmanaged directory'
$InstallDirectory=Join-Path $testRoot 'NewApp';'Unrelated launcher'|Set-Content $launcher
Install-MotivationWallpaper|Out-Null
Assert ((Test-Path (Join-Path $InstallDirectory 'installation.json')) -and (Get-Content $launcher) -eq 'Unrelated launcher') 'A fresh install ignores an unrelated Change Wallpaper.cmd'
# Exercise the actual task helpers with cmdlet mocks; never touch Task Scheduler.
Set-Item Function:Register-WallpaperTask $registerImplementation
Set-Item Function:Remove-WallpaperTask $removeImplementation
$script:taskCalls=@();$script:fixtureScriptPath=Join-Path $testRoot 'Managed\SetMotivationWallpaper.ps1'
function Get-ScheduledTask {
 param($TaskName,$TaskPath,$ErrorAction)
 $script:taskCalls+=@{operation='get';path=$TaskPath}
 if($TaskPath -ne '\'){throw 'Unscoped lookup would match another task folder.'}
 return @{Actions=@(@{Arguments=('-File "'+$script:fixtureScriptPath+'"')})}
}
function New-ScheduledTaskAction {param($Execute,$Argument,$WorkingDirectory);return 'action'}
function New-ScheduledTaskTrigger {param([switch]$Daily,$At,[switch]$AtLogOn,$User);return 'trigger'}
function New-ScheduledTaskPrincipal {param($UserId,$LogonType,$RunLevel);return 'principal'}
function New-ScheduledTaskSettingsSet {param([switch]$StartWhenAvailable,$MultipleInstances,[switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries,$ExecutionTimeLimit);return 'settings'}
function Register-ScheduledTask {param($TaskName,$TaskPath,$Action,$Trigger,$Principal,$Settings,$Description,[switch]$Force);$script:taskCalls+=@{operation='register';path=$TaskPath}}
function Stop-ScheduledTask {param($TaskName,$TaskPath,$ErrorAction);$script:taskCalls+=@{operation='stop';path=$TaskPath}}
function Unregister-ScheduledTask {param($TaskName,$TaskPath,$Confirm);$script:taskCalls+=@{operation='remove';path=$TaskPath}}
Register-WallpaperTask $script:fixtureScriptPath $testRoot
Remove-WallpaperTask 'MotivationWallpaper' $script:fixtureScriptPath
Assert ($script:taskCalls.Count -eq 5 -and @($script:taskCalls|Where-Object{$_.path -ne '\'}).Count -eq 0) 'Task lookup, registration, stop, and removal are scoped to the root folder'
Write-Output "Installation fixtures retained at $testRoot"
