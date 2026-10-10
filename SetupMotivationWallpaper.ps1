[CmdletBinding()]
param([string]$InstallDirectory="$env:LOCALAPPDATA\MotivationWallpaper",[switch]$NoSchedule,[switch]$CredentialsOnly,[ValidateSet('Commons','Generated')][string]$BackgroundSource,[ValidateSet('Basic','Jev')][string]$QuoteScreening)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'WallpaperPreferences.ps1')
function Get-WallpaperDesktopPath { [Environment]::GetFolderPath('DesktopDirectory') }
function Get-WallpaperStartMenuPath { [Environment]::GetFolderPath('Programs') }
# Draws the app icon into the installation. The icon is generated, so the repository holds no image files.
function New-WallpaperIcon($Directory) {
 if(!('Motivation.AppIcon' -as [type])){Add-Type -Path (Join-Path $Directory 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing}
 $icon=Join-Path $Directory 'MotivationWallpaper.ico'
 [Motivation.AppIcon]::Save($icon)
 return $icon
}
# powershell.exe always opens a console before -WindowStyle Hidden applies.
# This windowless launcher starts it without a console, so nothing flashes.
function New-WallpaperSettingsLauncher($Directory,$Icon) {
 $source=@'
using System;using System.Diagnostics;using System.IO;
static class SettingsLauncher {
 static void Main(){
  var directory=Path.GetDirectoryName(typeof(SettingsLauncher).Assembly.Location);
  var start=new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),@"WindowsPowerShell\v1.0\powershell.exe"),"-NoProfile -ExecutionPolicy Bypass -File \""+Path.Combine(directory,"ConfigureMotivationWallpaper.ps1")+"\"");
  start.UseShellExecute=false;start.CreateNoWindow=true;start.WorkingDirectory=directory;
  Process.Start(start);
 }
}
'@
 $launcher=Join-Path $Directory 'MotivationWallpaperSettings.exe'
 $temporary=Join-Path $Directory ('settings-launcher.'+[guid]::NewGuid().ToString('N')+'.tmp.exe')
 $parameters=New-Object CodeDom.Compiler.CompilerParameters
 $parameters.GenerateExecutable=$true;$parameters.OutputAssembly=$temporary;$parameters.ReferencedAssemblies.Add('System.dll')|Out-Null
 $parameters.CompilerOptions='/target:winexe /win32icon:"'+$Icon+'"'
 # The compiler is called directly: Add-Type would load and cache the result, so a rerun would skip the build.
 try {
  $result=(New-Object Microsoft.CSharp.CSharpCodeProvider).CompileAssemblyFromSource($parameters,$source)
  if($result.Errors.HasErrors){throw 'Settings launcher compilation failed: '+(@($result.Errors|Where-Object{!$_.IsWarning}|ForEach-Object{$_.ErrorText}) -join '; ')}
  Move-Item -LiteralPath $temporary -Destination $launcher -Force
 }
 finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Force}}
 return $launcher
}
function New-WallpaperShortcut($Path,$Directory) {
 $shell=New-Object -ComObject WScript.Shell
 try {
  $link=$shell.CreateShortcut($Path)
  $link.TargetPath=Join-Path $Directory 'MotivationWallpaperSettings.exe';$link.Arguments=''
  $link.WorkingDirectory=$Directory;$link.Description='Motivation Wallpaper settings'
  $link.IconLocation=(Join-Path $Directory 'MotivationWallpaper.ico')+',0'
  $link.Save()
 }finally{[Runtime.InteropServices.Marshal]::ReleaseComObject($shell)|Out-Null}
}
function Register-WallpaperTask($ScriptPath,$Directory) {
 $taskName='MotivationWallpaper'
 $existing=Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
 if($existing -and @($existing.Actions|Where-Object{$_.Arguments.Contains('-File "'+$ScriptPath+'"')}).Count -ne 1){throw 'Scheduled task belongs to another installation.'}
 $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$ScriptPath+'" -Automatic') -WorkingDirectory $Directory
 $triggers=@((New-ScheduledTaskTrigger -Daily -At '09:00'),(New-ScheduledTaskTrigger -AtLogOn -User $user))
 $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
 $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
 Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Description 'Daily motivational wallpaper.' -Force|Out-Null
}
function Install-MotivationWallpaper {
 if($CredentialsOnly){Set-WallpaperCredentials;Write-Output 'Credentials configured.';return}
 $target=[IO.Path]::GetFullPath($InstallDirectory).TrimEnd('\')
 if($target.Contains('"') -or $target.Contains('%') -or $target -match '[\r\n]'){throw 'Unsupported installation path.'}
 $manifestPath=Join-Path $target 'installation.json';$prior=$null
 if(Test-Path -LiteralPath $target){
  if(!(Test-Path -LiteralPath $manifestPath)){throw 'Directory exists and is not managed by this installer. Choose another -InstallDirectory.'}
  $prior=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
  if($prior.product -ne 'MotivationWallpaper' -or $prior.directory -ne $target){throw 'Installation ownership does not match.'}
 }
 $scriptPath=Join-Path $target 'SetMotivationWallpaper.ps1'
 $settingsPath=Join-Path $target 'ConfigureMotivationWallpaper.ps1'
 $shortcuts=@((Join-Path (Get-WallpaperDesktopPath) 'Wallpaper Settings.lnk'),(Join-Path (Get-WallpaperStartMenuPath) 'Motivation Wallpaper Settings.lnk'))
 foreach($shortcut in $shortcuts){if((Test-Path -LiteralPath $shortcut) -and !(Test-WallpaperShortcutOwner $shortcut $settingsPath)){throw "Settings shortcut belongs to another installation: $shortcut"}}
 $payload=@('SetMotivationWallpaper.ps1','BackgroundProviders.ps1','WallpaperStorage.ps1','WallpaperPreferences.ps1','ConfigureMotivationWallpaper.ps1','commons-backgrounds.json','MotivationWallpaper.cs','RestoreMotivationWallpaper.ps1','SetupMotivationWallpaper.ps1','UninstallMotivationWallpaper.ps1','README.md','LICENSE')
 foreach($name in $payload){if(!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $name))){throw "Missing release file: $name"}}
 $dataFolder=Join-Path $env:USERPROFILE 'Pictures\MotivationalWallpapers'
 $screening=if($QuoteScreening){$QuoteScreening}else{Get-WallpaperQuoteScreening $dataFolder}
 if($screening -eq 'Jev'){Set-WallpaperCredentials}
 New-Item -ItemType Directory -Path $target -Force|Out-Null
 foreach($name in $payload){$source=Join-Path $PSScriptRoot $name;$destination=Join-Path $target $name;if([IO.Path]::GetFullPath($source) -ne $destination){Copy-Item -LiteralPath $source -Destination $destination -Force}}
 $null=New-WallpaperSettingsLauncher $target (New-WallpaperIcon $target)
 $manifest=@{product='MotivationWallpaper';version='0.1.7';directory=$target;shortcuts=$shortcuts;taskName='';files=@($payload)+@('MotivationWallpaperSettings.exe','MotivationWallpaper.ico')}
 if($prior){$manifest.taskName=$prior.taskName}
 $manifest|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $manifestPath -Encoding UTF8
 if(!$NoSchedule){Register-WallpaperTask $scriptPath $target;$manifest.taskName='MotivationWallpaper';$manifest|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $manifestPath -Encoding UTF8}
 foreach($shortcut in $shortcuts){New-WallpaperShortcut $shortcut $target}
 # Wallpaper Settings replaces the Change Wallpaper.cmd launcher of earlier releases.
 if($prior -and $prior.PSObject.Properties['launcher'] -and $prior.launcher -and (Test-Path -LiteralPath $prior.launcher)){
  $old=[IO.File]::ReadAllText($prior.launcher)
  if([IO.Path]::GetFileName($prior.launcher) -eq 'Change Wallpaper.cmd' -and $old.Contains('rem MotivationWallpaper managed launcher') -and $old.Contains($scriptPath)){Remove-Item -LiteralPath $prior.launcher}
 }
 if($QuoteScreening){Set-WallpaperQuoteScreening $dataFolder $QuoteScreening}
 if($BackgroundSource){Set-WallpaperBackgroundSource $dataFolder $BackgroundSource}
 Write-Output "Installed in $target. Open Wallpaper Settings from the desktop or Start menu."
 if($NoSchedule){Write-Output 'No schedule added. Any existing managed schedule is retained.'}
}
if($MyInvocation.InvocationName -ne '.'){try{Install-MotivationWallpaper}catch{Write-Error $_;exit 1}}
