[CmdletBinding()]
param([string]$InstallDirectory="$env:LOCALAPPDATA\MotivationWallpaper")
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')
function Remove-WallpaperTask($Name,$ScriptPath) {
 $task=Get-ScheduledTask -TaskName $Name -TaskPath '\' -ErrorAction SilentlyContinue
 if(!$task){return}
 if(@($task.Actions|Where-Object{$_.Arguments.Contains('-File "'+$ScriptPath+'"')}).Count -ne 1){throw 'Scheduled task ownership does not match; nothing removed.'}
 Stop-ScheduledTask -TaskName $Name -TaskPath '\' -ErrorAction SilentlyContinue
 Unregister-ScheduledTask -TaskName $Name -TaskPath '\' -Confirm:$false
}
function Uninstall-MotivationWallpaper {
 $target=[IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\');$manifestPath=Join-Path $target 'installation.json'
 if(!(Test-Path -LiteralPath $manifestPath)){throw 'No managed installation found.'}
 $manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
 if($manifest.product -ne 'MotivationWallpaper' -or $manifest.directory -ne $target){throw 'Installation ownership does not match.'}
 $allowed=@('SetMotivationWallpaper.ps1','BackgroundProviders.ps1','WallpaperStorage.ps1','WallpaperPreferences.ps1','ConfigureMotivationWallpaper.ps1','commons-backgrounds.json','MotivationWallpaper.cs','RestoreMotivationWallpaper.ps1','SetupMotivationWallpaper.ps1','UninstallMotivationWallpaper.ps1','README.md','LICENSE','MotivationWallpaperSettings.exe','MotivationWallpaper.ico')
 foreach($name in $manifest.files){if($name -notin $allowed){throw 'Invalid installation file list; nothing removed.'}}
 if($manifest.taskName -and $manifest.taskName -ne 'MotivationWallpaper'){throw 'Invalid scheduled task name; nothing removed.'}
 $scriptPath=Join-Path $target 'SetMotivationWallpaper.ps1'
 # Only manifests from earlier releases record a Change Wallpaper.cmd launcher.
 $launcher=if($manifest.PSObject.Properties['launcher']){[string]$manifest.launcher}else{''}
 if($launcher -and [IO.Path]::GetFileName($launcher) -ne 'Change Wallpaper.cmd'){throw 'Invalid launcher path; nothing removed.'}
 if($launcher -and (Test-Path -LiteralPath $launcher)){$content=[IO.File]::ReadAllText($launcher);if(!$content.Contains('rem MotivationWallpaper managed launcher') -or !$content.Contains($scriptPath)){throw 'Launcher ownership does not match; nothing removed.'}}
 # Manifests from earlier releases have no shortcuts.
 $shortcuts=@(if($manifest.PSObject.Properties['shortcuts']){$manifest.shortcuts})
 $settingsPath=Join-Path $target 'ConfigureMotivationWallpaper.ps1'
 foreach($shortcut in $shortcuts){
  if([IO.Path]::GetFileName($shortcut) -notin @('Wallpaper Settings.lnk','Motivation Wallpaper Settings.lnk')){throw 'Invalid shortcut path; nothing removed.'}
  if((Test-Path -LiteralPath $shortcut) -and !(Test-WallpaperShortcutOwner $shortcut $settingsPath)){throw 'Shortcut ownership does not match; nothing removed.'}
 }
 if($manifest.taskName){Remove-WallpaperTask $manifest.taskName $scriptPath}
 if($launcher -and (Test-Path -LiteralPath $launcher)){Remove-Item -LiteralPath $launcher}
 foreach($shortcut in $shortcuts){if(Test-Path -LiteralPath $shortcut){Remove-Item -LiteralPath $shortcut}}
 foreach($name in $manifest.files){$file=Join-Path $target $name;if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file}}
 Remove-Item -LiteralPath $manifestPath
 if(@(Get-ChildItem -LiteralPath $target -Force).Count -eq 0){Remove-Item -LiteralPath $target}
 Write-Output 'Uninstalled. Wallpapers, history, and user API keys retained. Current wallpaper stays in place.'
}
if($MyInvocation.InvocationName -ne '.'){try{Uninstall-MotivationWallpaper}catch{Write-Error $_;exit 1}}
