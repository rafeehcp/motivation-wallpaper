$ErrorActionPreference='Stop'
$path=Join-Path $env:USERPROFILE 'Pictures\MotivationalWallpapers\previous-wallpapers.json'
if(!(Test-Path $path)){throw 'No previous wallpaper state has been recorded.'}
Add-Type -Path (Join-Path $PSScriptRoot 'MotivationWallpaper.cs') -ReferencedAssemblies System.Drawing
$desktop=New-Object Motivation.Desktop
try{$state=Get-Content $path -Raw|ConvertFrom-Json;foreach($item in $state.wallpapers){$desktop.Set($item.monitor,$item.path)};$desktop.SetPosition($state.position)}finally{$desktop.Dispose()}
