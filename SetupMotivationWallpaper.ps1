[CmdletBinding()]
param([string]$InstallDirectory="$env:LOCALAPPDATA\MotivationWallpaper",[switch]$NoSchedule,[switch]$CredentialsOnly,[ValidateSet('Commons','Generated')][string]$BackgroundSource='Commons')
$ErrorActionPreference='Stop'
function Set-WallpaperCredentials {
 Add-Type -AssemblyName System.Windows.Forms
 $names=@('TYPESAFE_API_KEY')
 foreach($name in $names) {
  if([Environment]::GetEnvironmentVariable($name,'User')){continue}
  $form=New-Object Windows.Forms.Form
  try {
   $form.Text="Motivation Wallpaper - $name";$form.Width=520;$form.Height=200;$form.StartPosition='CenterScreen'
   $label=New-Object Windows.Forms.Label;$label.Text="Enter $name. Saved in your Windows user environment.";$label.SetBounds(20,20,460,40);$form.Controls.Add($label)
   $box=New-Object Windows.Forms.TextBox;$box.UseSystemPasswordChar=$true;$box.SetBounds(20,65,460,25);$form.Controls.Add($box)
   $save=New-Object Windows.Forms.Button;$save.Text='Save key';$save.SetBounds(360,105,120,30);$save.DialogResult=[Windows.Forms.DialogResult]::OK;$form.Controls.Add($save);$form.AcceptButton=$save
   if($form.ShowDialog() -ne [Windows.Forms.DialogResult]::OK){throw 'Credential setup cancelled.'}
   $value=$box.Text.Trim();if(!$value){throw "No $name entered."}
   [Environment]::SetEnvironmentVariable($name,$value,'User');$box.Clear();$value=$null
  }finally{$form.Dispose()}
 }
}
function Get-WallpaperDesktopPath { [Environment]::GetFolderPath('DesktopDirectory') }
function Register-WallpaperTask($ScriptPath,$Directory) {
 $taskName='MotivationWallpaper'
 $existing=Get-ScheduledTask -TaskName $taskName -TaskPath '\' -ErrorAction SilentlyContinue
 if($existing -and @($existing.Actions|Where-Object{$_.Arguments.Contains('-File "'+$ScriptPath+'"')}).Count -ne 1){throw 'Scheduled task belongs to another installation.'}
 $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$ScriptPath+'" -Automatic -BackgroundSource '+$BackgroundSource) -WorkingDirectory $Directory
 $triggers=@((New-ScheduledTaskTrigger -Daily -At '09:00'),(New-ScheduledTaskTrigger -AtLogOn -User $user))
 $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
 $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 15)
 Register-ScheduledTask -TaskName $taskName -TaskPath '\' -Action $action -Trigger $triggers -Principal $principal -Settings $settings -Description 'Daily Jev-screened motivational wallpaper.' -Force|Out-Null
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
 $launcher=Join-Path (Get-WallpaperDesktopPath) 'Change Wallpaper.cmd';$scriptPath=Join-Path $target 'SetMotivationWallpaper.ps1'
 if((Test-Path -LiteralPath $launcher) -and (!$prior -or $prior.launcher -ne $launcher -or !([IO.File]::ReadAllText($launcher)).Contains($scriptPath))){throw 'Desktop launcher belongs to another installation.'}
 $payload=@('SetMotivationWallpaper.ps1','BackgroundProviders.ps1','commons-backgrounds.json','MotivationWallpaper.cs','RestoreMotivationWallpaper.ps1','SetupMotivationWallpaper.ps1','UninstallMotivationWallpaper.ps1','README.md','LICENSE')
 foreach($name in $payload){if(!(Test-Path -LiteralPath (Join-Path $PSScriptRoot $name))){throw "Missing release file: $name"}}
 Set-WallpaperCredentials
 New-Item -ItemType Directory -Path $target -Force|Out-Null
 foreach($name in $payload){$source=Join-Path $PSScriptRoot $name;$destination=Join-Path $target $name;if([IO.Path]::GetFullPath($source) -ne $destination){Copy-Item -LiteralPath $source -Destination $destination -Force}}
 $manifest=@{product='MotivationWallpaper';version='0.1.0';directory=$target;launcher=$launcher;taskName='';files=$payload;backgroundSource=$BackgroundSource}
 if($prior){$manifest.taskName=$prior.taskName}
 $manifest|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $manifestPath -Encoding UTF8
 if(!$NoSchedule){Register-WallpaperTask $scriptPath $target;$manifest.taskName='MotivationWallpaper';$manifest|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $manifestPath -Encoding UTF8}
 $lines=@('@echo off','chcp 65001 >nul','rem MotivationWallpaper managed launcher','title Change motivational wallpaper',('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "'+$scriptPath+'" -BackgroundSource '+$BackgroundSource),'if errorlevel 1 (','  echo Wallpaper could not be changed. See the error above.','  pause',')')
 [IO.File]::WriteAllLines($launcher,$lines,(New-Object Text.UTF8Encoding($false)))
 Write-Output "Installed in $target. Double-click Change Wallpaper.cmd on your desktop."
 if($NoSchedule){Write-Output 'No schedule added. Any existing managed schedule is retained.'}
}
if($MyInvocation.InvocationName -ne '.'){try{Install-MotivationWallpaper}catch{Write-Error $_;exit 1}}
