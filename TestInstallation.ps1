$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SetupMotivationWallpaper.ps1')
. (Join-Path $PSScriptRoot 'UninstallMotivationWallpaper.ps1')
$registerImplementation=${function:Register-WallpaperTask}
$removeImplementation=${function:Remove-WallpaperTask}
$testRoot=Join-Path $env:TEMP ('MotivationInstallTests-'+[guid]::NewGuid().ToString('N'))
$script:testDesktop=Join-Path $testRoot 'Desktop'
New-Item -ItemType Directory -Path $script:testDesktop -Force|Out-Null
function Get-WallpaperDesktopPath {return $script:testDesktop}
function Set-WallpaperCredentials {}
$script:schedules=0;$script:removed=0
function Register-WallpaperTask($ScriptPath,$Directory){$script:schedules++}
function Remove-WallpaperTask($Name,$ScriptPath){$script:removed++}
function Assert($Condition,$Message){if(!$Condition){throw "FAIL: $Message"};Write-Output "PASS: $Message"}
$InstallDirectory=Join-Path $testRoot ('App with spaces '+[char]0x00e9);$NoSchedule=$true;$CredentialsOnly=$false
Install-MotivationWallpaper
$launcher=Join-Path $script:testDesktop 'Change Wallpaper.cmd'
Assert ((Test-Path $launcher) -and $script:schedules -eq 0) 'Manual-only installation creates launcher without scheduling'
$text=[IO.File]::ReadAllText($launcher)
Assert ($text.Contains('-File "'+(Join-Path $InstallDirectory 'SetMotivationWallpaper.ps1')+'"') -and $text.Contains('if errorlevel 1 (')) 'Launcher quotes paths and pauses only on error'
Assert ($text.Contains([string][char]0x00e9) -and $text.Contains('chcp 65001 >nul')) 'Launcher preserves Unicode installation paths'
Assert ($text.Contains('-BackgroundSource Commons') -and (Test-Path (Join-Path $InstallDirectory 'commons-backgrounds.json'))) 'Installation includes Commons collection and launcher source choice'
$fixtureScript=Join-Path $InstallDirectory 'SetMotivationWallpaper.ps1'
@("'ok' | Set-Content (Join-Path `$PSScriptRoot 'launcher-result.txt')",'exit 0')|Set-Content -LiteralPath $fixtureScript -Encoding ASCII
& $env:ComSpec /d /c ('"'+$launcher+'"')
Assert ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $InstallDirectory 'launcher-result.txt'))) 'Real launcher executes successfully with spaces and Unicode and exits without a pause'
Install-MotivationWallpaper
Assert ($script:schedules -eq 0) 'Repeated manual-only setup succeeds'
$NoSchedule=$false;Install-MotivationWallpaper
Assert ($script:schedules -eq 1) 'Scheduled setup requests task registration'
$NoSchedule=$true;Install-MotivationWallpaper
$manifestPath=Join-Path $InstallDirectory 'installation.json'
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
Assert ($manifest.taskName -eq 'MotivationWallpaper') 'Manual-only rerun retains ownership of previous schedule'
# Reject path traversal in an edited manifest before removing anything.
$manifest.files+=@('..\outside.txt');$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
$rejected=$false;try{Uninstall-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*Invalid installation file list*'}
Assert ($rejected -and (Test-Path $launcher) -and $script:removed -eq 0) 'Invalid uninstall manifest preserves installation and task'
$manifest.files=@($manifest.files|Where-Object{$_ -ne '..\outside.txt'});$manifest|ConvertTo-Json -Depth 4|Set-Content $manifestPath
$retained=Join-Path $InstallDirectory 'personal-file.txt';'Keep me'|Set-Content $retained
Uninstall-MotivationWallpaper
Assert ((Test-Path $retained) -and !(Test-Path $launcher) -and $script:removed -eq 1) 'Uninstall removes managed files and schedule but retains unrelated files'
$InstallDirectory=Join-Path $testRoot 'Unmanaged';New-Item -ItemType Directory $InstallDirectory|Out-Null
$rejected=$false;try{Install-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*not managed*'}
Assert $rejected 'Setup refuses an unmanaged directory'
$InstallDirectory=Join-Path $testRoot 'NewApp';'Unrelated launcher'|Set-Content $launcher
$rejected=$false;try{Install-MotivationWallpaper}catch{$rejected=$_.Exception.Message -like '*launcher belongs*'}
Assert ($rejected -and !(Test-Path $InstallDirectory)) 'Setup refuses an unrelated desktop launcher before writing files'
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
